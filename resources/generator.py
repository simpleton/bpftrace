#
# Copyright (C) 2019 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

"""
This is reimplementation of logci in resources/CMakeLists.txt. The purpose of
the script is to bundle a number of header files as c strings.
"""

import argparse
import os

def parse_args():
    parser = argparse.ArgumentParser(
        description="Budnles provided headers as c++ source"
    )
    parser.add_argument("headers", nargs="+")
    parser.add_argument(
        "-o", "--output",
        required=True,
        help="file to write bundled headers to"
    )
    return parser.parse_args()

def main():
    args = parse_args()
    with open(args.output, "w+") as out:
        out.write("#include \"headers.h\"\n")
        out.write("namespace bpftrace {\n")

        for header_path in args.headers:
            with open(header_path) as header:
                content = header.read()
            header_name = os.path.basename(header_path)
            var_name = header_name.replace(".", "_")
            out.write("const char {}[] =R\"CONTENTS({})CONTENTS\";\n".format(
                var_name, content
            ))
            out.write("const unsigned {}_len = {};\n".format(var_name, len(content)))

        out.write("}\n")

if __name__ == "__main__":
    main()
