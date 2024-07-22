# Docker Image for TeX Live and Tectonic

This is an image with a Pandoc-optimized LaTeX environment on the basis of the `mambaorg/micromamba` image, which itself is (currently) based on Debian `bookwork-slim`. 

As [Academic in Heaven](https://github.com/academicinheaven) is based on `micromamba` and the official Debian packages for `texlive` are typically rather outdated, we install `texlive` from the official sources, based on the on the `pandoc-latex`  and `pandoc-extra` stages from
<https://raw.githubusercontent.com/pandoc/dockerfiles/master/ubuntu/Dockerfile>.

As a fall-back, we also install the [Tectonic Typesetting System](https://tectonic-typesetting.github.io/en-US/). Note that this requires network access by the container.

## Build and Installation

## Usage

## Updating

### Update all relevant git submodules
```bash
git submodule update --init --recursive
cd ../git_submodules/dockerfiles
# Fetch the latest changes
git fetch
# Check out the latest commit or the specific branch
git checkout main  # Replace 'main' with the branch you are tracking
git pull           # Pull the latest changes
# Navigate back to the root of the main repository
cd ../..
# Stage the changes to the submodule
git add git_submodules/dockerfiles
# Commit the changes
git commit -m "Updated submodule to the latest commit"
# Push the changes to the remote repository
git push
```
### Use `build.sh` with `--latest`

The `versions.txt` file contains the latest stable versions for all components.

### Update `seccomp-default.json`

Should be done in main project.

## Old

Issues:
- Multi-arch / arm64 support (https://github.com/islandoftex/texlive has it)
- Pandoc Latex may have it

1. Likely start with https://github.com/kjarosh/latex-docker
    - Alternatively take Pandoc Docker as a starting point, e.g.
        - https://github.com/pandoc/dockerfiles/blob/master/common/latex/install-texlive.sh
2. But build for arm64 or multi-arch
3. Use non-root user!
4. Use profile and package lists from Pandoc Docker and Eisvogel
    - Pandoc Docker
        - https://github.com/pandoc/dockerfiles/tree/master/common/latex
            - https://github.com/pandoc/dockerfiles/blob/master/common/latex/packages.txt
            - https://github.com/pandoc/dockerfiles/blob/master/common/latex/texlive.profile
        - https://github.com/pandoc/dockerfiles/blob/master/common/extra/packages.txt
    - https://github.com/Wandmalfarbe/pandoc-latex-template#texlive
    - https://github.com/Wandmalfarbe/pandoc-latex-template/blob/master/.texlife.profile