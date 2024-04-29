const { execSync } = require('child_process');
const fs = require('fs');

// get current branch
const currentBranch = execSync('git branch --show-current').toString().trim();

// Parse command-line arguments
const args = process.argv.slice(2);
const branchName = args?.find(arg => arg.startsWith('--branch='))?.split('=')[1];
const commitMessage = args?.find(arg => arg.startsWith('--message='))?.split('=')[1];

if (!branchName || !commitMessage) {
  console.error(`Please provide the branch name and commit message. --branch='publish-branch' --message='Publish files'`);
  return process.exit(1);
}

// Read the package.json file
const packageJson = JSON.parse(fs.readFileSync('package.json', 'utf8'));

// Get the files specified in the package.json:files field
const filesToPublish = packageJson.files;

// Create a new branch for publishing
const publishBranch = 'publish-branch';
execSync(`git checkout -B ${publishBranch}`);

// Stage and commit the files
execSync(`git add --force ${filesToPublish.join(' ')}`);
execSync(`git commit -m "${commitMessage}"`);

// Push the branch to GitHub
execSync(`git push origin ${publishBranch}`);

console.log('Files published to GitHub successfully!');

execSync(`git checkout ${currentBranch}`)
