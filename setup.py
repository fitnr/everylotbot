#!/usr/bin/env python
# -*- coding: utf-8 -*-

# This file is part of everylotnyc.

from setuptools import setup

setup(
    name='everylot',
    version='0.3.0',
    description='everylot',
    long_description='''every lot''',
    keywords='',
    author='fitnr',
    author_email='fitnr@fakeisthenewreal',
    packages=['everylot'],
    license='GPL-3.0',
    include_package_data=False,
    install_requires=[
        'twitter_bot_utils<=0.10.4',
    ],
    entry_points={
        'console_scripts': [
            'everylot=everylot.bot:main',
        ],
    },
    test_suite='tests',
)
