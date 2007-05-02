#!/bin/sh
cd ..
export MACOSX_DEPLOYMENT_TARGET=10.3
make

./bundle_up_dependencies
# ./finalize

