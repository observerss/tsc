#!/usr/bin/env python
import sys
from setuptools import setup
from setuptools.command.install import install
from setuptools import find_packages
from tsc import __version__


class MyInstall(install):
    def build(self):
        import os
        import sys
        os.system('python -c "import tsc"')

    def run(self):
        install.run(self)
        self.execute(self.build, (),
                     msg="Running post install task")
    

setup(name='tsc',
      version=__version__,
      description='TimeSeries Compressor',
      author='Jingchao Hu',
      author_email='jingchaohu@gmail.com',
      url='http://github.com/observerss/tsc',
      packages=find_packages(),
      package_data={'tsc': ['*.pyx']},
      include_package_data=True,
      install_requires=['numpy', 'cython', 'brotli', 'pandas'],
      python_requires='>=3.5',
      cmdclass={'install': MyInstall},
      classifiers=[
        'Development Status :: 4 - Beta',
        'Intended Audience :: Developers',
        'Topic :: System :: Archiving :: Compression',
        'License :: OSI Approved :: MIT License',
        'Programming Language :: Python :: 3',
      ]
     )
