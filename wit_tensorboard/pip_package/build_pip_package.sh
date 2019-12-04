#!/bin/sh
# Copyright 2018 The TensorFlow Authors. All Rights Reserved.
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

set -e
if [ -z "${RUNFILES}" ]; then
  RUNFILES="$(CDPATH= cd -- "$0.runfiles" && pwd)"
fi

if [ "$(uname)" = "Darwin" ]; then
  sedi="sed -i ''"
else
  sedi="sed -i"
fi

set -x
command -v virtualenv >/dev/null
command -v npm >/dev/null
[ -d "${RUNFILES}" ]

plugin_runfile_dir="${RUNFILES}/ai_google_pair_wit"

dest="/tmp/wit-pip"
mkdir -p "$dest"
cd "$dest"

mkdir -p release
pushd release

# Copy over all necessary files from witwidget
cp -LR "$plugin_runfile_dir/wit_tensorboard" .

# Move files related to pip building to pwd.
mv -f "wit_tensorboard/pip_package/README.rst" .
mv -f "wit_tensorboard/pip_package/setup.py" .
rm -rf wit_tensorboard/pip_package

# Copy over other built resources
cp "$plugin_runfile_dir/tf_interactive_inference_dashboard/wit_jupyter.*" witwidget/static

find . -name __init__.py | xargs chmod -x  # which goes for all genfiles

# Copy interactive inference common utils over and ship it as part of the pip package.
mkdir -p wit_tensorboard/_utils
cp "$plugin_runfile_dir/utils/common_utils.py" wit_tensorboard/_utils
cp "$plugin_runfile_dir/utils/inference_utils.py" wit_tensorboard/_utils
cp "$plugin_runfile_dir/utils/platform_utils.py" wit_tensorboard/_utils
touch wit_tensorboard/_utils/__init__.py

# Fix the import statements to reflect the copied over path.
find wit_tensorboard -name \*.py |
  xargs $sedi -e '
    s/^from utils/from wit_tensorboard._utils/
  '

virtualenv venv
export VIRTUAL_ENV=venv
export PATH="$PWD/venv/bin:${PATH}"
unset PYTHON_HOME

# # Require wheel for bdist_wheel command, and setuptools 36.2.0+ so that
# # env markers are handled (https://github.com/pypa/setuptools/pull/1081)
pip install -qU wheel 'setuptools>=36.2.0'

python setup.py bdist_wheel --python-tag py3 --project_name witwidget >/dev/null
python setup.py bdist_wheel --python-tag py2 --project_name witwidget >/dev/null
python setup.py bdist_wheel --python-tag py3 --project_name witwidget-gpu >/dev/null
python setup.py bdist_wheel --python-tag py2 --project_name witwidget-gpu >/dev/null

ls -hal "$PWD/dist"
