#!/bin/bash -ex
# Copyright 2017 The TensorFlow Authors. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ==============================================================================
# Builds protobuf 3 for cross compilation. Requires these environment variables
# to be set up to work correctly:
# TARGET_SYSROOT: Folder containing /usr/include, etc for your device.
# TARGET_CXX: C++ compiler for the target device.
# TARGET_CC: C compiler for the target device.
# Optional variables are:
# TARGET_NAME: Used to name files related to this build, default is "arm".
# JOB_COUNT: How many builds to run in parallel.
# TARGET_BIN_PATH: Location of binary tools for building the target.
# TARGET_CXXFLAGS: Extra flags to pass to the C++ compiler.
# TARGET_CCFLAGS: Extra flags to pass to the C compiler.

SCRIPT_DIR=$(dirname $0)
source "${SCRIPT_DIR}/build_helper.subr"
JOB_COUNT="${JOB_COUNT:-$(get_job_count)}"
TARGET_NAME="${TARGET_NAME:-arm}"

if [[ -z "${TARGET_SYSROOT}" ]]
then
  echo "You need to set TARGET_SYSROOT"
  exit 1
fi

if [[ ! -f "${SCRIPT_DIR}/Makefile" ]]; then
    echo "Makefile not found in ${SCRIPT_DIR}" 1>&2
    exit 1
fi

cd "${SCRIPT_DIR}"
if [ $? -ne 0 ]
then
    echo "cd to ${SCRIPT_DIR} failed." 1>&2
    exit 1
fi

GENDIR="$(pwd)/gen/protobuf-${TARGET_NAME}"
HOST_GENDIR="$(pwd)/gen/protobuf-host"
mkdir -p "${GENDIR}"
mkdir -p "${GENDIR}/${TARGET_NAME}"
clean=true

if [[ ! -f "./downloads/protobuf/autogen.sh" ]]; then
    echo "You need to download dependencies before running this script." 1>&2
    echo "tensorflow/contrib/makefile/download_dependencies.sh" 1>&2
    exit 1
fi

cd downloads/protobuf

PROTOC_PATH="${HOST_GENDIR}/bin/protoc"
if [[ ! -f "${PROTOC_PATH}" || ${clean} == true ]]; then
  # Try building compatible protoc first on host
  echo "protoc not found at ${PROTOC_PATH}. Building it first."
  make_host_protoc "${HOST_GENDIR}"
else
  echo "protoc found. Skip building host tools."
fi

export PATH="${TARGET_BIN_PATH}:$PATH"
export SYSROOT=${TARGET_SYSROOT}
export CC="${TARGET_CC} --sysroot ${TARGET_SYSROOT} ${TARGET_CCFLAGS}"
export CXX="${TARGET_CXX} --sysroot ${TARGET_SYSROOT} ${TARGET_CXXFLAGS}"

./autogen.sh
if [ $? -ne 0 ]
then
  echo "./autogen.sh command failed."
  exit 1
fi

./configure --prefix="${GENDIR}" \
--host="${TARGET_NAME}" \
--with-sysroot="${SYSROOT}" \
--disable-shared \
--enable-cross-compile \
--with-protoc="${PROTOC_PATH}" \
CFLAGS="${march_option}" \
CXXFLAGS="-frtti -fexceptions ${march_option}" \
LDFLAGS="" \
LIBS="-llog -lz"

if [ $? -ne 0 ]
then
  echo "./configure command failed."
  exit 1
fi

if [[ ${clean} == true ]]; then
  echo "clean before build"
  make clean
fi

make -j"${JOB_COUNT}" VERBOSE=1
if [ $? -ne 0 ]
then
  echo "make command failed."
  exit 1
fi

make install

echo "$(basename $0) finished successfully!!!"
