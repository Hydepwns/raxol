import { test, expect } from '@playwright/test';

test.describe('Terminal End-to-End Tests', () => {
  test.beforeEach(async ({ page }) => {
    // Navigate to the application
    await page.goto('/');
  });

  test('displays terminal interface', async ({ page }) => {
    // Check if the terminal is visible
    await expect(page.locator('.terminal-container')).toBeVisible();
    await expect(page.locator('[role="textbox"]')).toBeVisible();
  });

  test('handles keyboard input and displays output', async ({ page }) => {
    // Type a command
    await page.locator('[role="textbox"]').fill('echo "Hello, World!"');
    await page.keyboard.press('Enter');
    
    // Check if the output is displayed
    await expect(page.locator('.terminal-output')).toContainText('Hello, World!');
  });

  test('handles terminal resize', async ({ page }) => {
    // Get the initial size
    const initialSize = await page.locator('.terminal-container').boundingBox();
    
    // Resize the window
    await page.setViewportSize({ width: 800, height: 600 });
    
    // Wait for resize to complete
    await page.waitForTimeout(500);
    
    // Get the new size
    const newSize = await page.locator('.terminal-container').boundingBox();
    
    // Check if the size has changed
    expect(newSize.width).not.toBe(initialSize.width);
    expect(newSize.height).not.toBe(initialSize.height);
  });

  test('handles terminal theme change', async ({ page }) => {
    // Click the theme toggle button
    await page.locator('.theme-toggle').click();
    
    // Check if the theme has changed
    const backgroundColor = await page.locator('.terminal-container').evaluate(
      (el) => window.getComputedStyle(el).backgroundColor
    );
    
    // The theme should have changed from the default
    expect(backgroundColor).not.toBe('rgb(0, 0, 0)');
  });

  test('handles terminal history navigation', async ({ page }) => {
    // Type multiple commands
    await page.locator('[role="textbox"]').fill('echo "Command 1"');
    await page.keyboard.press('Enter');
    
    await page.locator('[role="textbox"]').fill('echo "Command 2"');
    await page.keyboard.press('Enter');
    
    await page.locator('[role="textbox"]').fill('echo "Command 3"');
    await page.keyboard.press('Enter');
    
    // Clear the input
    await page.locator('[role="textbox"]').fill('');
    
    // Navigate through history with up arrow
    await page.keyboard.press('ArrowUp');
    await expect(page.locator('[role="textbox"]')).toHaveValue('echo "Command 3"');
    
    await page.keyboard.press('ArrowUp');
    await expect(page.locator('[role="textbox"]')).toHaveValue('echo "Command 2"');
    
    await page.keyboard.press('ArrowUp');
    await expect(page.locator('[role="textbox"]')).toHaveValue('echo "Command 1"');
    
    // Navigate back down
    await page.keyboard.press('ArrowDown');
    await expect(page.locator('[role="textbox"]')).toHaveValue('echo "Command 2"');
  });

  test('handles terminal copy and paste', async ({ page }) => {
    // Type some text
    await page.locator('[role="textbox"]').fill('Text to copy');
    
    // Select the text
    await page.locator('[role="textbox"]').click({ clickCount: 3 });
    
    // Copy the text
    await page.keyboard.press('Control+C');
    
    // Clear the input
    await page.locator('[role="textbox"]').fill('');
    
    // Paste the text
    await page.keyboard.press('Control+V');
    
    // Check if the text was pasted
    await expect(page.locator('[role="textbox"]')).toHaveValue('Text to copy');
  });
}); 