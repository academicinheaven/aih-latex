#!/bin/bash

# Check if pdflatex is installed
if ! command -v pdflatex &> /dev/null; then
    echo "FAILED: pdflatex could not be found"
    exit 1
fi
echo "PASSED: pdflatex is installed"

# Check if tectonic is installed
if ! command -v tectonic &> /dev/null; then
    echo "FAILED: tectonic could not be found"
    exit 1
fi
echo "PASSED: tectonic is installed"

mkdir -p /tmp/tests
rm -f /tmp/tests/*

# Compile the TeX file with pdflatex
pdflatex -interaction=batchmode -output-directory /tmp/tests test.tex > /dev/null 2>&1
# Check if the PDF was created
if [ -f /tmp/tests/test.pdf ]; then
    echo "PASSED: pdflatex successfully compiled the TeX file"
    rm -f /tmp/tests/*
else
    echo "FAILED: pdflatex failed to compile the TeX file"
    exit 1
fi

# Compile the TeX file with tectonic
tectonic --outdir /tmp/tests test.tex > /dev/null 2>&1
# Check if the PDF was created
if [ -f /tmp/tests/test.pdf ]; then
    echo "PASSED: tectonic successfully compiled the TeX file"
    rm -f /tmp/tests/*
    exit 0
else
    echo "FAILED: tectonic failed to compile the TeX file"
    exit 1
fi