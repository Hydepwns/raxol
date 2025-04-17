import * as vscode from "vscode";
import { RaxolPanelManager } from "./RaxolPanelManager";

export function activate(context: vscode.ExtensionContext) {
  console.log("Raxol extension is now active");

  // Register command to show the Raxol Terminal panel
  context.subscriptions.push(
    vscode.commands.registerCommand("raxol.showTerminal", () => {
      RaxolPanelManager.createOrShow(context);
    })
  );

  // Ensure the panel manager is disposed if it exists when the extension deactivates
  context.subscriptions.push({
    dispose: () => {
      RaxolPanelManager.currentPanel?.dispose();
    },
  });
}

export function deactivate() {
  console.log("Raxol extension is now deactivated");
}
