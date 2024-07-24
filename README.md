# Docker Image for TeX Live and Tectonic

This is an image with a Pandoc-optimized LaTeX environment on the basis of the `mambaorg/micromamba` image, which itself is (currently) based on Debian `bookwork-slim`. 

As [Academic in Heaven](https://github.com/academicinheaven) is based on [`micromamba`](https://micromamba-docker.readthedocs.io/en/latest/) and the official Debian packages for `texlive` are typically rather outdated, we install `texlive` from the official sources, based on the on the `pandoc-latex`  and `pandoc-extra` stages from
<https://raw.githubusercontent.com/pandoc/dockerfiles/master/ubuntu/Dockerfile>.

This also allows installing missing packages via `tlmgr install`.

As a fall-back, we also install the [Tectonic Typesetting System](https://tectonic-typesetting.github.io/en-US/). Note that this requires network access by the container and a writeable host system.


## Build and Installation

The preferred way of building the images for Apple silicon is to use `build.sh` on an Apple M1 machine. You need Docker Desktop installed.

```bash
# Clone from Github
git clone https://github.com/academicinheaven/aih-latex
cd aih-latex
# Initialize Submodules
git submodule update --init --recursive
# Build
./build.sh
```

```bash
Usage: ./build.sh [ --help ] [ test | push | freeze | update ]

Commands(s):
  (none): Build image
  test:   Run tests
  push:   Push Docker image to repository
  freeze: Create version folder and freeze version.txt and env.yaml.lock
  update: Update submodules and external files
```

Here is the full process:

1. Make sure that `IMAGE_TAG` in `version.txt` is set properly; it will also determine the tag on Docker Hub.
2. Update all dependencies with `./build.sh update`.
3. Edit `versions.txt` as needed.
2. Build and test with `./build.sh` from a branch of your choice.
3. Freeze all components with `./build.sh freeze`.
4. Edit `README.md`.
5. Add a tag / release.
6. Commit / push to Github.
7. Push to Docker Hub with `./build.sh push`.

## Usage

```bash
docker run --rm -it --mount type=bind,source="$(pwd)",target=/usr/aih/data/src \
    mfhepp/aih-latex:latest  \
     /bin/bash
```

## Updating

1. Check latest versions for
  - [`micromamba-docker`](https://github.com/mamba-org/micromamba-docker/releases/)
  - ['tectonic` on `conda-forge`](https://anaconda.org/conda-forge/tectonic) and on the [Tectonic Web site](https://tectonic-typesetting.github.io/en-US/).
3. Make sure `freeze/x.y.z/versions.txt` exists for the current version. If not, create it with `./build.sh freeze`.
4. Create a new branch: `git checkout -b update_xyz`
5. Edit `versions.txt` and update all versions **and set `IMAGE_TAG` to the new  version identifier,** which is always `<texlive-year>-<tectonic-version>`. 
6. Update all Git submodules  and other files with  `./build.sh update`. This essentially does the following:
```bash
# Update git submodules
   git submodule update --init --recursive
   cd dockerfiles
   git fetch
   git checkout main  # Replace 'main' with the branch you are tracking
   git pull           # Pull the latest changes
   cd ..
   # staging / commit / push will be up to the developer
   # Fetching the latest seccomp profile from https://github.com/moby/moby/blob/master/profiles/seccomp/default.json
   curl https://raw.githubusercontent.com/moby/moby/master/profiles/seccomp/default.json -o seccomp-default.json
```
7. Try to build and test the updated combinations with `./build.sh`
8. If successful, produce a release:
  - Run  `./build.sh freeze`; this will create  a new folder in `freeze` and copy `versions.txt` and `env.yaml.lock`.
  - Support for `pip` is currently missing. (This is  not needed in this component of Academic in Heaven, but we aim at a unified approach.)
  - Add a release note to README.md (currently manual)
  - Create a release on Github (currently manual)
9. Commit, merge with main, add a tag, and push to Github.
10. Currently manually: Attach the `latest` tag to the latest version
```bash
docker login
docker pull mfhepp/aih-latex:2014-0.15.0
docker tag mfhepp/aih-latex:2014-0.15.0 mfhepp/aih-latex:latest
docker push mfhepp/aih-latex:latest
```

## Components

1. [`micromamba-docker`](https://github.com/mamba-org/micromamba-docker)
2. [TeX Live](https://www.tug.org/texlive/)
3. [`tectonic`](https://tectonic-typesetting.github.io/en-US/).
4. [pandoc-dockerfiles](https://github.com/pandoc/dockerfiles) mostly for the TeX installation process and recommended settings for TeX Live.

## Releases and Tags

The version numbering for `aih-latex` is based on the combination of  **the  TeX Live version** and the `tectonic` release tag. `latest` is the latest available version.

| Tag / Release | TeX Live version | Tectonic version | micromamba-docker  version | Image tag on Docker Hub |
| --- | --- | --- |
| latest | 2024 | 0.15.0 | 1.5.8 | [mfhepp/aih-latex:latest](https://hub.docker.com/repository/docker/mfhepp/aih-latex/general) |
| 2024-0.15.0 | 2024 | 0.15.0 | 1.5.8 | [mfhepp/aih-latex:latest](https://hub.docker.com/repository/docker/mfhepp/aih-latex/general) |

The versions for `latest` are stored in [`versions.txt`](versions.txt). The versions for each previous release will be in in `freeze/<version>/versions.txt`.

**Note:** There is currently no tracking for versions of LaTeX components.

## License and Acknowledgments

We thankfully acknowledge the following components:

- [micromamba-docker](https://github.com/mamba-org/micromamba-docker) under [Apache 2.0](https://github.com/mamba-org/micromamba-docker/blob/main/LICENSE)
- [TeX Live](https://www.tug.org/texlive/) under the [liberal TeX license](https://www.tug.org/texlive/LICENSE.TL)
- [`tectonic`](https://github.com/tectonic-typesetting/tectonic) under the [MIT License](https://github.com/tectonic-typesetting/tectonic/blob/master/LICENSE)
- [pandoc-dockerfiles](https://github.com/pandoc/dockerfiles) under [GPL 2.0](https://github.com/pandoc/dockerfiles/blob/master/LICENSE)
- The [`seccomp` profile from the Moby project](https://github.com/moby/moby/tree/master) under [Apache 2.0](https://github.com/moby/moby/blob/master/LICENSE)