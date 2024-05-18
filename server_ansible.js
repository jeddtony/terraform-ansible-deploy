function executeCommand(command, args, listener) {
    const spawn = require('child_process').spawn;
  const subprocess = spawn(command, args);
  subprocess.stdout.on('data', listener);

  subprocess.stdout.pipe(process.stdout);
  subprocess.stderr.pipe(process.stderr);
process.stdin.pipe(subprocess.stdin);

subprocess.on('exit', () => process.exit())
  subprocess.on('error', (err) => {
    console.error(`Failed to start subprocess: ${err}`);
  });
  }

//   ansible-playbook -vvvv --private-key=~/.ssh/id_rsa add_ssh_keys.yml
  executeCommand('ansible-playbook', ['-vvvv', '--private-key=~/.ssh/id_rsa', 'add_ssh_keys.yml'], (output) => {
      console.log('about to show a line of output');
    console.log(output.toString());
  });