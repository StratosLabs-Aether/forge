const vscode = require('vscode');
const fs = require('fs');
const path = require('path');

function taskTemplate() {
  return {
    version: '2.0.0',
    tasks: [
      {
        label: 'Run Current Aether File',
        type: 'shell',
        command: 'aether',
        args: ['${file}'],
        group: 'build',
        presentation: {
          reveal: 'always',
          panel: 'shared',
          clear: false
        },
        problemMatcher: []
      },
      {
        label: 'Lint Current Aether File',
        type: 'shell',
        command: 'aether',
        args: ['lint', '${file}'],
        presentation: {
          reveal: 'always',
          panel: 'shared',
          clear: false
        },
        problemMatcher: []
      },
      {
        label: 'Check Current Aether File',
        type: 'shell',
        command: 'aether',
        args: ['check', '${file}'],
        presentation: {
          reveal: 'always',
          panel: 'shared',
          clear: false
        },
        problemMatcher: []
      },
      {
        label: 'Format Current Aether File',
        type: 'shell',
        command: 'aether',
        args: ['fmt', '${file}'],
        presentation: {
          reveal: 'always',
          panel: 'shared',
          clear: false
        },
        problemMatcher: []
      },
      {
        label: 'Aether REPL',
        type: 'shell',
        command: 'aether',
        args: ['repl'],
        presentation: {
          reveal: 'always',
          panel: 'shared',
          clear: false
        },
        problemMatcher: []
      },
      {
        label: 'Run Aether Tests',
        type: 'shell',
        command: 'aether',
        args: ['test', '${workspaceFolder}/tests'],
        presentation: {
          reveal: 'always',
          panel: 'shared',
          clear: false
        },
        problemMatcher: []
      }
    ]
  };
}

function launchTemplate() {
  return {
    version: '0.2.0',
    configurations: [
      {
        name: 'Run Current Aether File',
        type: 'aether',
        request: 'launch',
        program: '${file}',
        cwd: '${fileDirname}'
      },
      {
        name: 'Debug Current Aether File',
        type: 'aether',
        request: 'launch',
        program: '${file}',
        debug: true,
        cwd: '${fileDirname}'
      }
    ]
  };
}

function writeJsonFile(filePath, value) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, JSON.stringify(value, null, 2) + '\n', 'utf8');
}

function configureWorkspaceFiles(workspaceDir, overwrite) {
  const tasksPath = path.join(workspaceDir, '.vscode', 'tasks.json');
  const launchPath = path.join(workspaceDir, '.vscode', 'launch.json');

  if (!overwrite && (fs.existsSync(tasksPath) || fs.existsSync(launchPath))) {
    return false;
  }

  writeJsonFile(tasksPath, taskTemplate());
  writeJsonFile(launchPath, launchTemplate());
  return true;
}

function shellQuote(filePath) {
  return '"' + filePath.replace(/"/g, '\\"') + '"';
}

function shellCommandInDir(command, cwdPath) {
  const quotedDir = shellQuote(cwdPath);
  return 'cd ' + quotedDir + ' && ' + command;
}

function runInAetherTerminal(command) {
  const terminalName = 'Aether';
  let terminal = vscode.window.terminals.find((t) => t.name === terminalName);
  if (!terminal) {
    terminal = vscode.window.createTerminal(terminalName);
  }
  terminal.show(true);
  terminal.sendText(command);
}

function getFilePathFromDebugConfig(config) {
  if (config && typeof config.program === 'string' && config.program.trim()) {
    return config.program;
  }
  const editor = vscode.window.activeTextEditor;
  if (editor && editor.document && editor.document.uri && editor.document.uri.scheme === 'file') {
    return editor.document.fileName;
  }
  return '';
}

function normalizeFilePath(rawPath) {
  if (!rawPath) {
    return '';
  }
  const expanded = rawPath
    .replace(/\$\{file\}/g, vscode.window.activeTextEditor?.document?.fileName || '')
    .replace(/\$\{fileDirname\}/g, vscode.window.activeTextEditor ? path.dirname(vscode.window.activeTextEditor.document.fileName) : '')
    .replace(/\$\{workspaceFolder\}/g, getWorkspaceFolderFromContext()?.uri?.fsPath || '');
  return expanded;
}

function collectBreakpointsForFile(filePath) {
  const wanted = path.resolve(filePath);
  const lines = [];
  for (const bp of vscode.debug.breakpoints) {
    if (!(bp instanceof vscode.SourceBreakpoint)) {
      continue;
    }
    if (!bp.location || !bp.location.uri || bp.location.uri.scheme !== 'file') {
      continue;
    }
    const bpFile = path.resolve(bp.location.uri.fsPath);
    if (bpFile === wanted) {
      lines.push(bp.location.range.start.line + 1);
    }
  }
  lines.sort((a, b) => a - b);
  return lines;
}

function getWorkspaceFolderFromContext() {
  const editor = vscode.window.activeTextEditor;
  if (editor) {
    const folder = vscode.workspace.getWorkspaceFolder(editor.document.uri);
    if (folder) {
      return folder;
    }
  }

  if (vscode.workspace.workspaceFolders && vscode.workspace.workspaceFolders.length > 0) {
    return vscode.workspace.workspaceFolders[0];
  }

  return null;
}

function scaffoldProject(projectDir, projectName) {
  fs.mkdirSync(projectDir, { recursive: false });
  fs.mkdirSync(path.join(projectDir, 'tests'), { recursive: true });

  const mainSrc = '#! ' + projectName + ' entry script\n\n' +
    'say: "Hello from Aether"\n';

  const testSrc = 'assert_eq;\n' +
    '    2 + 2\n' +
    '    4\n' +
    '    "math should work"\n';

  const readme = '# ' + projectName + '\n\n' +
    '## Run\n\n' +
    '```bash\n' +
    'aether main.ath\n' +
    '```\n\n' +
    '## Test\n\n' +
    '```bash\n' +
    'aether test tests\n' +
    '```\n';

  fs.writeFileSync(path.join(projectDir, 'main.ath'), mainSrc, 'utf8');
  fs.writeFileSync(path.join(projectDir, 'tests', 'smoke.ath'), testSrc, 'utf8');
  fs.writeFileSync(path.join(projectDir, 'README.md'), readme, 'utf8');
  configureWorkspaceFiles(projectDir, true);
}

function activate(context) {
  const debugProvider = vscode.debug.registerDebugConfigurationProvider('aether', {
    resolveDebugConfiguration(folder, config) {
      const rawProgram = getFilePathFromDebugConfig(config);
      const program = normalizeFilePath(rawProgram);

      if (!program || !program.toLowerCase().endsWith('.ath')) {
        vscode.window.showErrorMessage('Aether debug needs an .ath file. Open an Aether file or set "program" in launch.json.');
        return undefined;
      }

      const cwd = config.cwd
        ? normalizeFilePath(config.cwd)
        : path.dirname(program);

      const isDebug = config.debug !== false;
      const breakpoints = collectBreakpointsForFile(program);
      const breakArg = breakpoints.length > 0 ? ' --break=' + breakpoints.join(',') : '';
      const command = isDebug
        ? 'aether --debug' + breakArg + ' ' + shellQuote(program)
        : 'aether ' + shellQuote(program);

      return {
        type: 'node-terminal',
        name: config.name || (isDebug ? 'Debug Current Aether File' : 'Run Current Aether File'),
        request: 'launch',
        command,
        cwd
      };
    }
  });

  const newProjectCommand = vscode.commands.registerCommand('aether.newProject', async () => {
    const targetFolder = await vscode.window.showOpenDialog({
      canSelectFiles: false,
      canSelectFolders: true,
      canSelectMany: false,
      openLabel: 'Select Parent Folder for New Aether Project'
    });

    if (!targetFolder || targetFolder.length === 0) {
      return;
    }

    const projectName = await vscode.window.showInputBox({
      prompt: 'Aether project name',
      placeHolder: 'my-aether-app',
      validateInput: (value) => {
        if (!value || !value.trim()) {
          return 'Project name is required';
        }
        if (!/^[a-zA-Z0-9._-]+$/.test(value.trim())) {
          return 'Use letters, numbers, dot, underscore, or hyphen';
        }
        return null;
      }
    });

    if (!projectName) {
      return;
    }

    const parent = targetFolder[0].fsPath;
    const projectDir = path.join(parent, projectName.trim());

    if (fs.existsSync(projectDir)) {
      vscode.window.showErrorMessage('Target folder already exists: ' + projectDir);
      return;
    }

    try {
      scaffoldProject(projectDir, projectName.trim());
      const uri = vscode.Uri.file(projectDir);
      await vscode.commands.executeCommand('vscode.openFolder', uri, false);
    } catch (err) {
      vscode.window.showErrorMessage('Failed to create project: ' + err.message);
    }
  });

  const configureWorkspaceCommand = vscode.commands.registerCommand('aether.configureWorkspace', async () => {
    const folder = getWorkspaceFolderFromContext();
    if (!folder) {
      vscode.window.showErrorMessage('Open a folder/workspace first to configure Aether run/debug files.');
      return;
    }

    const workspaceDir = folder.uri.fsPath;
    const tasksPath = path.join(workspaceDir, '.vscode', 'tasks.json');
    const launchPath = path.join(workspaceDir, '.vscode', 'launch.json');
    const hasExisting = fs.existsSync(tasksPath) || fs.existsSync(launchPath);

    let overwrite = false;
    if (hasExisting) {
      const choice = await vscode.window.showWarningMessage(
        'Aether run/debug config already exists in this workspace. Overwrite it?',
        'Overwrite',
        'Cancel'
      );
      if (choice !== 'Overwrite') {
        return;
      }
      overwrite = true;
    }

    configureWorkspaceFiles(workspaceDir, overwrite);
    vscode.window.showInformationMessage('Aether run/debug workspace configuration is ready.');
  });

  const runCurrentFileCommand = vscode.commands.registerCommand('aether.runCurrentFile', async () => {
    const editor = vscode.window.activeTextEditor;
    if (!editor) {
      vscode.window.showErrorMessage('Open an .ath file first.');
      return;
    }

    const filePath = editor.document.fileName;
    if (!filePath.toLowerCase().endsWith('.ath')) {
      vscode.window.showErrorMessage('The active file is not an Aether (.ath) file.');
      return;
    }

    if (editor.document.isDirty) {
      await editor.document.save();
    }

    const fileDir = path.dirname(filePath);
    runInAetherTerminal(shellCommandInDir('aether ' + shellQuote(filePath), fileDir));
  });

  const debugCurrentFileCommand = vscode.commands.registerCommand('aether.debugCurrentFile', async () => {
    const editor = vscode.window.activeTextEditor;
    if (!editor) {
      vscode.window.showErrorMessage('Open an .ath file first.');
      return;
    }

    const filePath = editor.document.fileName;
    if (!filePath.toLowerCase().endsWith('.ath')) {
      vscode.window.showErrorMessage('The active file is not an Aether (.ath) file.');
      return;
    }

    if (editor.document.isDirty) {
      await editor.document.save();
    }

    const fileDir = path.dirname(filePath);
    const breakpoints = collectBreakpointsForFile(filePath);
    const breakArg = breakpoints.length > 0 ? ' --break=' + breakpoints.join(',') : '';
    runInAetherTerminal(
      shellCommandInDir('aether --debug' + breakArg + ' ' + shellQuote(filePath), fileDir)
    );
  });

  context.subscriptions.push(newProjectCommand);
  context.subscriptions.push(configureWorkspaceCommand);
  context.subscriptions.push(runCurrentFileCommand);
  context.subscriptions.push(debugCurrentFileCommand);
  context.subscriptions.push(debugProvider);
}

function deactivate() {}

module.exports = {
  activate,
  deactivate
};
