# Contributing to this repository <!-- omit in toc -->

## Getting started <!-- omit in toc -->

Before you begin:
- Have you read the [code of conduct](CODE_OF_CONDUCT.md)?
- Check out the [existing issues](https://github.com/figment-networks/kong-plugin-concurrent-connections-quota/issues).

### Ready to make a change? Fork the repo

Fork using GitHub Desktop:

- [Getting started with GitHub Desktop](https://docs.github.com/en/desktop/installing-and-configuring-github-desktop/getting-started-with-github-desktop) will guide you through setting up Desktop.
- Once Desktop is set up, you can use it to [fork the repo](https://docs.github.com/en/desktop/contributing-and-collaborating-using-github-desktop/cloning-and-forking-repositories-from-github-desktop)!

Fork using the command line:

- [Fork the repo](https://docs.github.com/en/github/getting-started-with-github/fork-a-repo#fork-an-example-repository) so that you can make your changes without affecting the original project until you're ready to merge them.

Fork with [GitHub Codespaces](https://github.com/features/codespaces):

- [Fork, edit, and preview](https://docs.github.com/en/free-pro-team@latest/github/developing-online-with-codespaces/creating-a-codespace) using [GitHub Codespaces](https://github.com/features/codespaces) without having to install and run the project locally.

### Make your update:
Make your changes to the file(s) you'd like to update.

### Self review
You should always review your own PR first.

Make sure that:
- [ ] Linter do not complains (`pongo lint`)
- [ ] Your changes are covered in specs
- [ ] Run tests and check if they all passed (`KONG_VERSION=nightly pongo run`)
- [ ] If there are any failing checks in your PR, troubleshoot them until they're all passing.

### Open a pull request
When you're done making changes and you'd like to propose them for review open your PR (pull request) with a clear list of what you've done.
Make sure you included specs.
Always write a clear log message for your commits. One-line messages are fine for small changes

### Submit your PR & get it reviewed
- Once you submit your PR, we will review it. The first thing you're going to want to do is a [self review](#self-review).
- After that, we may have questions, check back on your PR to keep up with the conversation.
- Did you have an issue, like a merge conflict? Check out [git tutorial](https://lab.github.com/githubtraining/managing-merge-conflicts) on how to resolve merge conflicts and other issues.

### Your PR is merged!
Congratulations! The whole community thanks you. :sparkles:
