#!/usr/bin/env node

/**
 * Script to delete all Cloudflare Pages deployments for the raxol project
 *
 * Usage:
 *   CF_API_TOKEN=your_token node delete-pages-deployments.js
 *
 * Or use wrangler's stored credentials (recommended):
 *   node delete-pages-deployments.js
 */

const https = require('https');
const { exec } = require('child_process');
const { promisify } = require('util');
const execAsync = promisify(exec);

const ACCOUNT_ID = 'b26522e30eea543fc256f68dea56f301';
const PROJECT_NAME = 'raxol';
const DELETE_ALIASED = process.env.CF_DELETE_ALIASED_DEPLOYMENTS === 'true';

async function getApiToken() {
  // Try environment variable first
  if (process.env.CF_API_TOKEN) {
    return process.env.CF_API_TOKEN;
  }

  // Try to get from wrangler
  try {
    const { stdout } = await execAsync('wrangler config get cloudflare_api_token 2>/dev/null');
    return stdout.trim();
  } catch (e) {
    console.error('ERROR: No API token found.');
    console.error('Please set CF_API_TOKEN environment variable or login with wrangler.');
    console.error('Get a token from: https://dash.cloudflare.com/profile/api-tokens');
    console.error('Token needs "Cloudflare Pages:Edit" permission.');
    process.exit(1);
  }
}

function makeRequest(options, data = null) {
  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => body += chunk);
      res.on('end', () => {
        try {
          const parsed = JSON.parse(body);
          if (!parsed.success) {
            reject(new Error(`API Error: ${JSON.stringify(parsed.errors)}`));
          } else {
            resolve(parsed);
          }
        } catch (e) {
          reject(new Error(`Failed to parse response: ${body}`));
        }
      });
    });

    req.on('error', reject);
    if (data) req.write(JSON.stringify(data));
    req.end();
  });
}

async function listDeployments(apiToken) {
  const options = {
    hostname: 'api.cloudflare.com',
    path: `/client/v4/accounts/${ACCOUNT_ID}/pages/projects/${PROJECT_NAME}/deployments`,
    method: 'GET',
    headers: {
      'Authorization': `Bearer ${apiToken}`,
      'Content-Type': 'application/json'
    }
  };

  return makeRequest(options);
}

async function deleteDeployment(apiToken, deploymentId) {
  const options = {
    hostname: 'api.cloudflare.com',
    path: `/client/v4/accounts/${ACCOUNT_ID}/pages/projects/${PROJECT_NAME}/deployments/${deploymentId}`,
    method: 'DELETE',
    headers: {
      'Authorization': `Bearer ${apiToken}`,
      'Content-Type': 'application/json'
    }
  };

  return makeRequest(options);
}

async function deleteAllDeployments() {
  console.log(`Deleting all deployments for project: ${PROJECT_NAME}`);
  console.log(`Account ID: ${ACCOUNT_ID}`);
  console.log(`Delete aliased deployments: ${DELETE_ALIASED}\n`);

  const apiToken = await getApiToken();

  let totalDeleted = 0;
  let totalSkipped = 0;
  let batchCount = 0;

  // Keep fetching and deleting until no more deployments
  while (true) {
    batchCount++;
    console.log(`\n--- Batch ${batchCount} ---`);
    console.log(`Fetching current deployments...`);

    const response = await listDeployments(apiToken);

    if (!response.result || response.result.length === 0) {
      console.log('No more deployments found.');
      break;
    }

    console.log(`Found ${response.result.length} deployments.`);

    let deletedInBatch = 0;
    for (const deployment of response.result) {
      const isProd = deployment.environment === 'production';
      const hasAlias = deployment.aliases && deployment.aliases.length > 0;

      // Skip production deployment unless DELETE_ALIASED is true
      if (isProd && !DELETE_ALIASED) {
        console.log(`  SKIP: ${deployment.id} (production deployment)`);
        totalSkipped++;
        continue;
      }

      // Skip aliased deployments unless DELETE_ALIASED is true
      if (hasAlias && !DELETE_ALIASED) {
        console.log(`  SKIP: ${deployment.id} (has aliases: ${deployment.aliases.join(', ')})`);
        totalSkipped++;
        continue;
      }

      try {
        console.log(`  DELETE: ${deployment.id} (${deployment.environment})`);
        await deleteDeployment(apiToken, deployment.id);
        totalDeleted++;
        deletedInBatch++;

        // Rate limiting - wait a bit between deletes
        await new Promise(resolve => setTimeout(resolve, 200));
      } catch (error) {
        console.error(`  ERROR deleting ${deployment.id}:`, error.message);
      }
    }

    console.log(`Deleted ${deletedInBatch} deployments in this batch.`);

    // If we didn't delete any in this batch and they were all skipped, we're done
    if (deletedInBatch === 0) {
      console.log('All remaining deployments are skipped. Done.');
      break;
    }

    // Wait a bit before fetching the next batch
    await new Promise(resolve => setTimeout(resolve, 1000));
  }

  console.log(`\n=== Summary ===`);
  console.log(`  Deleted: ${totalDeleted} deployments`);
  console.log(`  Skipped: ${totalSkipped} deployments`);

  if (totalSkipped > 0 && !DELETE_ALIASED) {
    console.log(`\nTo delete ALL deployments including production and aliased:`);
    console.log(`  CF_DELETE_ALIASED_DEPLOYMENTS=true node delete-pages-deployments.js`);
  }

  console.log(`\nAfter deleting all deployments, you can delete the project:`);
  console.log(`  wrangler pages project delete ${PROJECT_NAME}`);
}

// Run the script
deleteAllDeployments().catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});
