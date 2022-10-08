#!/bin/bash
set -e -x

# This file is not used by CI anymore. This only exists incase someone wants to
# generate manylinux wheels locally for testing

# By default, this file builds pygame all available python/pypy versions. If
# you only want to build on specific version(s), specify it here
export SUPPORTED_PYTHONS="/opt/python/*"

export PORTMIDI_INC_PORTTIME=1

# To 'solve' this issue:
#   >>> process 338: D-Bus library appears to be incorrectly set up; failed to read
#   machine uuid: Failed to open "/var/lib/dbus/machine-id": No such file or directory
if [ ! -f /var/lib/dbus/machine-id ]; then
    dbus-uuidgen > /var/lib/dbus/machine-id
fi


# -msse4 is required by old gcc in centos, for the SSE4.2 used in image.c
# -g0 removes debugging symbols reducing file size greatly.
# -03 is full optimization on.
export CFLAGS="-g0 -O3"

cd /io
ls -la
ls -la /opt/python/

export PIP_CONFIG_FILE=buildconfig/pip_config.ini

export SDL_AUDIODRIVER=disk
export SDL_VIDEODRIVER=dummy

# Compile wheels
for PYDIR in $SUPPORTED_PYTHONS; do
    rm -rf Setup build
    PYBIN="${PYDIR}/bin"
    PYTHON="${PYBIN}/python"
	if [ ! -f ${PYTHON} ]; then
	    PYTHON="${PYBIN}/pypy"
	fi

    # build docs in the wheel
    ${PYTHON} -m pip install Sphinx
    ${PYTHON} setup.py docs

    # make the wheel
    ${PYTHON} -m pip wheel -vvv -w wheelhouse .

    # Bundle external shared libraries into the wheels
    auditwheel repair wheelhouse/* -w buildconfig/manylinux-build/wheelhouse/
    rm -rf wheelhouse

    # install pygame from wheel and run tests
    ${PYTHON} -m pip install pygame --no-index -f /io/buildconfig/manylinux-build/wheelhouse
    (cd $HOME; ${PYTHON} -m pygame.tests -vv --exclude opengl,music,timing)
done
