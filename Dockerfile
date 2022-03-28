FROM nvidia/cuda:11.3.1-devel-ubuntu20.04

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
USER root

ENV \
    NB_USER=root \
    SHELL=/bin/bash \
    HOME="/${NB_USER}" \
    USER_GID=0 \
    DISPLAY=:1 \
    TERM=xterm \
    WORKSPACE_HOME=/workspace

# Copy a script that we will use to correct permissions after running certain commands
COPY scripts/clean-layer.sh  /usr/bin/clean-layer.sh
COPY scripts/fix-permissions.sh  /usr/bin/fix-permissions.sh
RUN \
    chmod a+rwx /usr/bin/clean-layer.sh && \
    chmod a+rwx /usr/bin/fix-permissions.sh 

# Install Ubuntu Package
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update --yes && \
    apt-get upgrade --yes && \
    apt-get install --yes --no-install-recommends \
	apt-utils \
	autoconf \
	automake \
	build-essential \
	ca-certificates \
	ccache \
	cmake \
	curl \
	fonts-liberation \
	git \
	libjpeg-dev \
	libpng-dev \
	libtool \
	locales \
	make \
	pandoc \
	run-one \
	sudo \
	tini \
	vim \
	wget && \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen && \
    clean-layer.sh

ENV \
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8

# Layer cleanup script
COPY scripts/clean-layer.sh  /usr/bin/clean-layer.sh
COPY scripts/fix-permissions.sh  /usr/bin/fix-permissions.sh

# Make clean-layer and fix-permissions executable
RUN chmod a+rwx /usr/bin/clean-layer.sh && chmod a+rwx /usr/bin/fix-permissions.sh

# Install Python
ENV \
    CONDA_DIR=/opt/conda \
    CONDA_ROOT=/opt/conda
ENV PATH="${CONDA_DIR}/bin:${PATH}"
ARG \
    PYTHON_VERSION=default \
    CONDA_MIRROR=https://github.com/conda-forge/miniforge/releases/latest/download

RUN set -x && \
    # Miniforge installer
    miniforge_arch=$(uname -m) && \
    miniforge_installer="Mambaforge-Linux-${miniforge_arch}.sh" && \
    wget --quiet "${CONDA_MIRROR}/${miniforge_installer}" && \
    /bin/bash "${miniforge_installer}" -f -b -p "${CONDA_DIR}" && \
    rm "${miniforge_installer}" && \
    # Conda configuration see https://conda.io/projects/conda/en/latest/configuration.html
    $CONDA_ROOT/bin/conda config --system --set auto_update_conda false && \
    $CONDA_ROOT/bin/conda config --system --set show_channel_urls true && \
    if [[ "${PYTHON_VERSION}" != "default" ]]; then $CONDA_ROOT/bin/mamba install --quiet --yes python="${PYTHON_VERSION}"; fi && \
    # Pin major.minor version of python
    $CONDA_ROOT/bin/mamba list python | grep '^python ' | tr -s ' ' | cut -d ' ' -f 1,2 >> "${CONDA_DIR}/conda-meta/pinned" && \
    # Using conda to update all packages: https://github.com/mamba-org/mamba/issues/1092
    $CONDA_ROOT/bin/conda update --all --quiet --yes && \
    $CONDA_ROOT/bin/conda clean --all -f -y && \
    fix-permissions.sh $CONDA_ROOT && \
    clean-layer.sh

# Install Jupyter
RUN mamba install --quiet --yes \
    'notebook' \
    'jupyterhub' \
    'jupyterlab' && \
    mamba clean --all -f -y && \
    npm cache clean --force && \
    jupyter notebook --generate-config && \
    jupyter lab clean && \
    fix-permissions.sh $CONDA_ROOT && \
    clean-layer.sh

# Notebook Branding
COPY branding/logo.png /tmp/logo.png
COPY branding/favicon.ico /tmp/favicon.ico
RUN /bin/bash -c 'cp /tmp/logo.png $(python -c "import sys; print(sys.path[-1])")/notebook/static/base/images/logo.png'
RUN /bin/bash -c 'cp /tmp/favicon.ico $(python -c "import sys; print(sys.path[-1])")/notebook/static/base/images/favicon.ico'
RUN /bin/bash -c 'cp /tmp/favicon.ico $(python -c "import sys; print(sys.path[-1])")/notebook/static/favicon.ico'

# Install Python Package
RUN pip install matplotlib

# /workspace
# Make folders
RUN \
    if [ -e $WORKSPACE_HOME ] ; then \
    chmod a+rwx $WORKSPACE_HOME; \
    else \
    mkdir $WORKSPACE_HOME && chmod a+rwx $WORKSPACE_HOME; \
    fi
ENV HOME=$WORKSPACE_HOME
WORKDIR $WORKSPACE_HOME

### Start Ainize Worksapce ###
COPY start.sh /scripts/start.sh
RUN ["chmod", "+x", "/scripts/start.sh"]
CMD "/scripts/start.sh"