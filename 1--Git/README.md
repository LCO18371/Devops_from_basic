# How to Create a GitHub Repository Using Command Line

This guide will walk you through the steps to create a GitHub repository using the command line.

## Prerequisites
Before starting, ensure the following:
1. Clear your terminal: `clear`
2. Update your system:  
    ```bash
    sudo apt update
    sudo apt upgrade
    ```
3. Install Git:  
    ```bash
    sudo apt install git
    ```
4. Verify Git installation:  
    ```bash
    git --version
    ```
5. Configure Git with your name and email:  
    ```bash
    git config --global user.name "Your Name"
    git config --global user.email "YourEmail@example.com"
    git config --global --list
    ```

## Steps to Create a GitHub Repository

1. **Create a Project Directory**  
    ```bash
    mkdir Devops_from_basic
    cd Devops_from_basic/
    ```

2. **Initialize Git**  
    ```bash
    git init
    ```

3. **Create a README File**  
    ```bash
    echo "# My Project" > README.md
    ```

4. **Stage and Commit Changes**  
    ```bash
    git add README.md
    git commit -m "Initial commit"
    ```

5. **Add Remote Repository**  
    Replace the URL with your repository URL:  
    ```bash
    git remote add origin https://github.com/YourUsername/YourRepo.git
    ```

6. **Push Changes to GitHub**  
    ```bash
    git branch -M main
    git push -u origin main
    ```

## Optional: Create a Remote Repository on GitHub Using the Command Line

You can use the GitHub CLI tool to create a GitHub repository directly from the command line.

### Install GitHub CLI (gh)
First, ensure you have the GitHub CLI installed. If not, install it as follows:

```bash
# Update your package list and install GitHub CLI on Ubuntu
sudo apt update
sudo apt install gh
```

Once the installation is complete, verify it:

```bash
gh --version
```

### Authenticate with GitHub
If this is your first time using `gh`, authenticate with your GitHub account:

```bash
gh auth login
```

Follow the prompts to log in. You can authenticate using a web browser or a token.

### Create a New Repository on GitHub Using CLI
After logging in, create a new GitHub repository by running:

```bash
gh repo create <repository-name> --public
```

Replace `<repository-name>` with your desired repository name. Use the `--public` flag to make it public or `--private` to make it private.

#### Example:
```bash
gh repo create my_project --public
```

You can also initialize the repository with a README, `.gitignore`, or a license:

```bash
gh repo create my_project --public --confirm --readme --license mit
```

- `--confirm`: Skips the confirmation step.
- `--readme`: Automatically creates a `README.md` file.
- `--license mit`: Adds the MIT license.

### Push Your Local Repository to GitHub
Once the repository is created, push your local repository to GitHub:

```bash
git remote add origin https://github.com/yourusername/my_project.git
git push -u origin main
```

Replace `yourusername` and `my_project` with your GitHub username and repository name, respectively.

You have now successfully created and pushed a GitHub repository using the command line!