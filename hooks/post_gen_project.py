#!/usr/bin/env python
import os

PROJECT_DIRECTORY = os.path.realpath(os.path.curdir)
ROOT_DIR_PATTERN = '$((ROOTDIR))'


if __name__ == '__main__':
    for root, dirs, files in os.walk(PROJECT_DIRECTORY):
        for filename in files:
            fullpath = os.path.join(root, filename)

            content = None

            for encoding in ('utf-8', 'latin-1'):
                try:
                    with open(os.path.join(root, filename), 'r', encoding=encoding) as fh:
                        content = fh.read()
                except UnicodeDecodeError:
                    pass

            if content is None or ROOT_DIR_PATTERN not in content:
                continue

            with open(fullpath, 'w', encoding=encoding) as fh:
                fh.write(content.replace(ROOT_DIR_PATTERN, PROJECT_DIRECTORY))
