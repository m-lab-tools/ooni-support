#!/usr/bin/env python2

import os
from os.path import abspath, dirname, join
import subprocess
from setuptools import setup, find_packages, Command


# Note: We follow PEP-0440 versioning:
# http://legacy.python.org/dev/peps/pep-0440/

VERSION = '0.1.dev0'

# Note: The dependency versions are chosen to match ooni-backend where they overlap:
TwistedDependency = 'twisted == 13.2.0' # BUG: Include the hash as per ooni-backend.


def run(*args):
    print 'Running: {0!r}'.format(args)
    try:
        subprocess.check_call(args, shell=False)
    except subprocess.CalledProcessError, e:
        print 'Process exited with {0!r} exit status.'.format(e.returncode)
        raise


class TestWithCoverageAndTrialInAVirtualEnvCommand (Command):
    """Run unit tests with coverage analysis and reporting in a virtualenv."""

    # Internal settings:
    TestToolRequirements = [
        TwistedDependency,
        'coverage == 3.7.1',
        'mock >= 1.0.1',
        ]

    description = __doc__

    user_options = [
    ]

    def __init__(self, dist):
        Command.__init__(self, dist)

        self.oonisupportdir = dirname(dirname(abspath(__file__)))
        self.pkgdir = join(self.oonisupportdir, 'mlab-ns-simulator')
        self.testdir = join(self.pkgdir, 'build', 'test')
        self.venvdir = join(self.testdir, 'venv')

        bindir = join(self.venvdir, 'bin')
        self.pip = join(bindir, 'pip')
        self.coverage = join(bindir, 'coverage')
        self.trial = join(bindir, 'trial')

    def initialize_options(self):
        pass

    def finalize_options(self):
        pass

    def run(self):
        self._initialize_virtualenv()
        self._install_testing_tools()

        pkgname = 'mlabsim'
        pypkg = join(self.pkgdir, pkgname)

        if 'PYTHONPATH' in os.environ:
            os.environ['PYTHONPATH'] = '{0}:{1}'.format(self.pkgdir, os.environ['PYTHONPATH'])
        else:
            os.environ['PYTHONPATH'] = self.pkgdir

        # Coverage and trial dump things into cwd, so cd:
        os.chdir(self.testdir)

        run(self.coverage, 'run', '--branch', '--source', pypkg, self.trial, pkgname)
        run(self.coverage, 'html')

    def _initialize_virtualenv(self):
        virtualenvscript = join(self.oonisupportdir, 'virtualenv', 'virtualenv.py')
        run('python2', virtualenvscript, '--no-site-packages', self.venvdir)

    def _install_testing_tools(self):
        reqspath = join(self.testdir, 'test-tool-requirements.txt')

        with file(reqspath, 'w') as f:
            for req in self.TestToolRequirements:
                f.write(req + '\n')

        run(self.pip, 'install', '--use-mirrors', '--requirement', reqspath)

setup(
    # Humanish metadata:
    name='mlab-ns-simulator',
    description='A simulator for the mlab-ns service which provides features Ooni needs.',
    version=VERSION,
    author='LeastAuthority',
    author_email='consultancy@leastauthority.com',
    license='FIXME',
    url='https://github.com/LeastAuthority/ooni-support',

    # Python structure for this package:
    packages=find_packages(),
    entry_points = {
        'console_scripts': [
            'mlabsim = mlabsim.main:main',
            ],
        },
    test_suite='mlabsim.tests',

    # Dependencies:
    install_requires=[
        TwistedDependency,
        'argparse == 1.2.1',
        ],

    # Command customization:
    cmdclass={
        'test': TestWithCoverageAndTrialInAVirtualEnvCommand,
        },
    )
