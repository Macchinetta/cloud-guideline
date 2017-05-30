# Macchinetta Server Framework Cloud Extension Development Guideline

This guideline helps to proceed with the software development (mainly coding) smoothly.

## Source files

Source files of this guideline are stored into following directories.

* Japanese version : `{repository root}/source/`


## Source file format

This guideline is written by the reStructuredText format(`.rst`).
About the reStructuredText format, refer to the [Sphinx documentation contents](http://sphinx-doc.org/contents.html).


## How to build

We build to HTML files using the [Sphinx](http://sphinx-doc.org/index.html).
About the Sphinx, refer to the [Sphinx documentation contents](http://sphinx-doc.org/contents.html).

### Install the Sphinx

Please install the Python and Sphinx.

* [Python](https://www.python.org/)
* [Sphinx](http://sphinx-doc.org/index.html)

### Clone a repository

Please clone a `Macchinetta/cloud-guideline` repository or forked your repository.

```
git clone https://github.com/Macchinetta/cloud-guideline.git
```

or

```
git clone https://github.com/{your account}/cloud-guideline.git
```

### Build HTML files

Please execute the `build-html.sh` or `build-html.bat`.
If build is successful, HTML files generate to the `{your repository}/build/html/` directory.

Linux or Mac:

```
$ cd {your repository directory}
$ ./build-html.sh
```

Windows:

```
> cd {your repository directory}
> build-html.bat
```

## Terms of use

Terms of use refer to [here](https://github.com/Macchinetta/cloud-guideline/blob/master/source/Introduction/TermOfUse.rst).
