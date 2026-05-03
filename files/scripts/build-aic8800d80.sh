#!/usr/bin/env bash
set -euo pipefail

# Install build dependencies
dnf install -y \
  rpm-build \
  make gcc \
  kernel-devel \
  kernel-headers \
  unzip \
  rpmdevtools

# Get the running kernel version (matches what's in the image)
KVER=$(rpm -q kernel-devel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}' | tail -1)
echo "Building for kernel: $KVER"

# Set up rpmbuild tree
rpmdev-setuptree

# Download the spec file
curl -fsSL \
  https://raw.githubusercontent.com/shenmintao/aic8800d80/refs/heads/main/bazzite/aic8800d80.spec \
  -o ~/rpmbuild/SPECS/aic8800d80.spec

# Fix 1: Remove dkms dep (not available/needed in container build — modules compile directly)
sed -i '/^BuildRequires:.*dkms/d' ~/rpmbuild/SPECS/aic8800d80.spec
sed -i '/^Requires:.*dkms/d' ~/rpmbuild/SPECS/aic8800d80.spec


# Download the source archive (as declared in the spec)
spectool -g -R ~/rpmbuild/SPECS/aic8800d80.spec

# Build the RPM, passing the kernel uname macro
rpmbuild -bb \
  --define "uname $KVER" \
  ~/rpmbuild/SPECS/aic8800d80.spec

# Install the built RPM
find ~/rpmbuild/RPMS/ -name "aic8800d80-*.rpm" -exec dnf install -y {} \;

# Rebuild module dependencies
depmod -a "$KVER"

# Clean up
dnf remove -y rpm-build rpmdevtools
dnf clean all
rm -rf ~/rpmbuild
