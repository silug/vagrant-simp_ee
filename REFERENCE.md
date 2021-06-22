# Reference

<!-- DO NOT EDIT: This document was generated by Puppet Strings -->

## Table of Contents

### Classes

* [`simp_ee::bootstrap`](#simp_eebootstrap): Run "simp bootstrap"
* [`simp_ee::classify`](#simp_eeclassify): Classify nodes
* [`simp_ee::config`](#simp_eeconfig): Configure for simp config
* [`simp_ee::install`](#simp_eeinstall): Installs SIMP
* [`simp_ee::keepalive`](#simp_eekeepalive): Enable ssh keepalives to avoid timeouts

### Plans

* [`simp_ee`](#simp_ee): Install SIMP Enterprise Edition
* [`simp_ee::check_puppetserver`](#simp_eecheck_puppetserver): Check the status of puppetserver
* [`simp_ee::scanner`](#simp_eescanner): Configure simp_scanner Puppet module

## Classes

### <a name="simp_eebootstrap"></a>`simp_ee::bootstrap`

Run "simp bootstrap"

#### Examples

##### 

```puppet
include simp_ee::bootstrap
```

### <a name="simp_eeclassify"></a>`simp_ee::classify`

Classify nodes

#### Parameters

The following parameters are available in the `simp_ee::classify` class:

* [`files`](#files)
* [`owner`](#owner)
* [`group`](#group)
* [`dirmode`](#dirmode)
* [`filemode`](#filemode)

##### <a name="files"></a>`files`

Data type: `Array`

Hiera files to manage

Default value: `[
    '/etc/puppetlabs/code/environments/production/hiera.yaml',
    '/etc/puppetlabs/code/environments/production/data/os/RedHat.yaml',
    '/etc/puppetlabs/code/environments/production/data/os/windows.yaml',
    '/etc/puppetlabs/code/environments/production/data/role/console.yaml',
    '/etc/puppetlabs/code/environments/production/data/role/puppet.yaml',
  ]`

##### <a name="owner"></a>`owner`

Data type: `String[1]`

User owner of managed files and directories

Default value: `'root'`

##### <a name="group"></a>`group`

Data type: `String[1]`

Group owner of managed files and directories

Default value: `'puppet'`

##### <a name="dirmode"></a>`dirmode`

Data type: `String[4]`

Permissions for managed directories

Default value: `'0750'`

##### <a name="filemode"></a>`filemode`

Data type: `String[4]`

Permissions for managed files

Default value: `'0640'`

### <a name="simp_eeconfig"></a>`simp_ee::config`

Configure for simp config

#### Examples

##### 

```puppet
include simp_ee::config
```

### <a name="simp_eeinstall"></a>`simp_ee::install`

Installs SIMP

#### Examples

##### 

```puppet
include simp_ee::install
```

#### Parameters

The following parameters are available in the `simp_ee::install` class:

* [`community_release`](#community_release)
* [`enterprise_release`](#enterprise_release)
* [`license_key`](#license_key)
* [`release_package`](#release_package)
* [`release_package_name`](#release_package_name)
* [`install_type`](#install_type)
* [`community_packages`](#community_packages)
* [`enterprise_packages`](#enterprise_packages)
* [`license_key_file`](#license_key_file)
* [`simprelease`](#simprelease)
* [`simpreleasetype`](#simpreleasetype)
* [`ee_simprelease`](#ee_simprelease)
* [`ee_simpreleasetype`](#ee_simpreleasetype)

##### <a name="community_release"></a>`community_release`

Data type: `String`

URL of the SIMP Community Edition release package

Default value: `'https://download.simp-project.com/simp-release-community.rpm'`

##### <a name="enterprise_release"></a>`enterprise_release`

Data type: `String`

URL of the SIMP Enterprise Edition release package

Default value: `'https://download.simp-project.com/simp-release-enterprise.rpm'`

##### <a name="license_key"></a>`license_key`

Data type: `Optional[String]`

License key for SIMP Enterprise Edition

Default value: ``undef``

##### <a name="release_package"></a>`release_package`

Data type: `String`



Default value: `$license_key`

##### <a name="release_package_name"></a>`release_package_name`

Data type: `String`



Default value: `(/(?:(?:-\d[^-]*){2})?\.rpm$/, '')`

##### <a name="install_type"></a>`install_type`

Data type: `Enum[
    'community',
    'enterprise'
  ]`



Default value: `('-')[-1]`

##### <a name="community_packages"></a>`community_packages`

Data type: `Array`



Default value: `[
    'simp-adapter',
    'simp',
    'puppetserver',
  ]`

##### <a name="enterprise_packages"></a>`enterprise_packages`

Data type: `Array`



Default value: `[
    'simp-enterprise',
  ]`

##### <a name="license_key_file"></a>`license_key_file`

Data type: `String`



Default value: `'/etc/simp/license.key'`

##### <a name="simprelease"></a>`simprelease`

Data type: `Optional[String]`



Default value: ``undef``

##### <a name="simpreleasetype"></a>`simpreleasetype`

Data type: `Optional[String]`



Default value: ``undef``

##### <a name="ee_simprelease"></a>`ee_simprelease`

Data type: `Optional[String]`



Default value: ``undef``

##### <a name="ee_simpreleasetype"></a>`ee_simpreleasetype`

Data type: `Optional[String]`



Default value: ``undef``

### <a name="simp_eekeepalive"></a>`simp_ee::keepalive`

Enable ssh keepalives to avoid timeouts

## Plans

### <a name="simp_ee"></a>`simp_ee`

Install SIMP Enterprise Edition

#### Parameters

The following parameters are available in the `simp_ee` plan:

* [`targets`](#targets)
* [`license_key`](#license_key)
* [`ip_subnet`](#ip_subnet)
* [`simprelease`](#simprelease)
* [`simpreleasetype`](#simpreleasetype)
* [`ee_simprelease`](#ee_simprelease)
* [`ee_simpreleasetype`](#ee_simpreleasetype)

##### <a name="targets"></a>`targets`

Data type: `TargetSpec`

The targets to run on

Default value: `'all'`

##### <a name="license_key"></a>`license_key`

Data type: `Optional[String[1]]`

A SIMP EE license key

Default value: `system::env('SIMP_LICENSE_KEY')`

##### <a name="ip_subnet"></a>`ip_subnet`

Data type: `String[5]`

The IP subnet range to use for the private network (the IP address with the last octet removed)

Default value: `system::env('VAGRANT_IP_SUBNET')`

##### <a name="simprelease"></a>`simprelease`

Data type: `Optional[String[1]]`

SIMP release version

Default value: `system::env('SIMP_RELEASE')`

##### <a name="simpreleasetype"></a>`simpreleasetype`

Data type: `Optional[String[1]]`

SIMP release type ("development", for example)

Default value: `system::env('SIMP_RELEASETYPE')`

##### <a name="ee_simprelease"></a>`ee_simprelease`

Data type: `Optional[String[1]]`

SIMP EE release version

Default value: `system::env('SIMP_EE_RELEASE')`

##### <a name="ee_simpreleasetype"></a>`ee_simpreleasetype`

Data type: `Optional[String[1]]`

SIMP EE release type ("development", for example

Default value: `system::env('SIMP_EE_RELEASETYPE')`

### <a name="simp_eecheck_puppetserver"></a>`simp_ee::check_puppetserver`

Check the status of puppetserver

#### Parameters

The following parameters are available in the `simp_ee::check_puppetserver` plan:

* [`targets`](#targets)

##### <a name="targets"></a>`targets`

Data type: `TargetSpec`

The targets to run on

### <a name="simp_eescanner"></a>`simp_ee::scanner`

Configure simp_scanner Puppet module

#### Parameters

The following parameters are available in the `simp_ee::scanner` plan:

* [`token`](#token)
* [`msi_pkg`](#msi_pkg)
* [`rpm_pkg`](#rpm_pkg)
* [`targets`](#targets)
* [`collector`](#collector)
* [`extra_config`](#extra_config)

##### <a name="token"></a>`token`

Data type: `String`

The SIMP Console registration token

##### <a name="msi_pkg"></a>`msi_pkg`

Data type: `Variant[
    Stdlib::HTTPUrl,
    Stdlib::HTTPSUrl
  ]`

URL of the scanner MSI

##### <a name="rpm_pkg"></a>`rpm_pkg`

Data type: `Variant[
    Stdlib::HTTPUrl,
    Stdlib::HTTPSUrl
  ]`

URL of the scanner RPM

##### <a name="targets"></a>`targets`

Data type: `TargetSpec`

The targets to run on

Default value: `'all'`

##### <a name="collector"></a>`collector`

Data type: `Variant[
    Undef,
    Stdlib::HTTPUrl,
    Stdlib::HTTPSUrl
  ]`

A collector URL to override the default

Default value: ``undef``

##### <a name="extra_config"></a>`extra_config`

Data type: `Hash`

Additional scanner collector configuration

Default value: `{}`
