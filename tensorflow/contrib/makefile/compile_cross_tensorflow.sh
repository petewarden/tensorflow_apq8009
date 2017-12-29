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
# Builds TensorFlow for cross compilation. Requires these environment variables
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

GENDIR=tensorflow/contrib/makefile/gen
LIBDIR=${GENDIR}/lib
LIB_PREFIX=libtensorflow-core

#remove any old artifacts
rm -rf ${LIBDIR}/${LIB_PREFIX}.a

export PATH="${TARGET_BIN_PATH}:$PATH"
export SYSROOT=${TARGET_SYSROOT}
export CC="${TARGET_CC} --sysroot ${TARGET_SYSROOT} ${TARGET_CCFLAGS}"
export CXX="${TARGET_CXX} --sysroot ${TARGET_SYSROOT} ${TARGET_CXXFLAGS}"

# Compile nsync for the host and the target device architecture.
# Don't use  export var=`something` syntax; it swallows the exit status.
HOST_NSYNC_LIB=`tensorflow/contrib/makefile/compile_nsync.sh`
export TARGET_NSYNC_CC="${TARGET_CXX}"
TARGET_NSYNC_LIB=`CC_PREFIX="${CC_PREFIX}" NDK_ROOT="${NDK_ROOT}" \
      tensorflow/contrib/makefile/compile_nsync.sh -t cross`
export HOST_NSYNC_LIB TARGET_NSYNC_LIB

make -j"${JOB_COUNT}" -f tensorflow/contrib/makefile/Makefile \
  TARGET=${TARGET_NAME} \
  CC="${CC}" \
  CXX="${CXX}" \
  CXXFLAGS="--std=c++11 -DIS_SLIM_BUILD -fno-exceptions -DTENSORFLOW_DISABLE_META \
  -O3 -D__ANDROID_TYPES_SLIM__" \
  LIBFLAGS="-Wl,--allow-multiple-definition -Wl,--whole-archive" \
  LDFLAGS="-Wl,--no-whole-archive -L${GENDIR}/protobuf-${TARGET_NAME}/lib -ldl -pthread" \
  HOST_NSYNC_LIB="${HOST_NSYNC_LIB}" \
  TARGET_NSYNC_LIB="${TARGET_NSYNC_LIB}"

echo "Done building and packaging TF"
file ${LIBDIR}/${LIB_PREFIX}.a
