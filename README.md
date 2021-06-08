# SIMP Enterprise Edition in Vagrant

- [SIMP Enterprise Edition in Vagrant](#simp-enterprise-edition-in-vagrant)
  - [Prerequisites](#prerequisites)
  - [Getting started](#getting-started)
    - [Set the `SIMP_LICENSE_KEY` environment variable](#set-the-simp_license_key-environment-variable)
    - [Set the `SIMP_AGENTS` environment variable](#set-the-simp_agents-environment-variable)
    - [Optional environment variables](#optional-environment-variables)
    - [Run `vagrant up`](#run-vagrant-up)
    - [Manual configuration](#manual-configuration)
  - [Using the Bolt plan on real servers](#using-the-bolt-plan-on-real-servers)
  - [Known issues](#known-issues)
    - [Windows agents with Fedora's `vagrant` package](#windows-agents-with-fedoras-vagrant-package)
    - [CentOS 8 agents with VirtualBox](#centos-8-agents-with-virtualbox)

## Prerequisites

You need to have the following installed:

* [Vagrant](https://www.vagrantup.com/downloads)
* A virtualization provider for Vagrant such as [VirtualBox](https://www.virtualbox.org/wiki/Downloads)
* [Bolt](https://puppet.com/docs/bolt/latest/bolt_installing.html)

## Getting started

### Set the `SIMP_LICENSE_KEY` environment variable

Set the environment variable `SIMP_LICENSE_KEY` to the contents of a valid SIMP
EE license key.

For example, if your license key is in the file `license.key`, the following
command can be used:

```
export SIMP_LICENSE_KEY=$( cat license.key )
```

**NOTE**: Without this environment variable set, the Bolt plan will set up SIMP
*Community Edition on the SIMP server and will skip the Console/Scanner setup.

### Set the `SIMP_AGENTS` environment variable

Set the `SIMP_AGENTS` environment variable to a space-separated list of agent
nodes to manage with Vagrant.

The following agent types are defined:

* win2012r2
* win2016
* win2019
* centos7
* centos8
* oel7
* oel8
* rhel7
* rhel8

(The full list can be seen (or modified) in [Vagrantfile](./Vagrantfile).)

For example, to start a Windows 2019 agent and a CentOS 7 agent, use the following command:

```
export SIMP_AGENTS='win2019 centos7'
```

**NOTE**: Without this environment variable set, Vagrant will start **all** defined agents.  This will require a large amount of RAM, and many of the agent types have not been tested and likely will not work.

### Optional environment variables

The following environment variables *can* be set if the defaults are not desirable:

* `VAGRANT_IP_SUBNET`: The private IP subnet used to communicate between the
    VMs.  Defaults to `10.10.16`.
* `VAGRANT_DOMAIN`: The DNS domain name used by the VMs.  Defaults to
    `simp-ee.test`.
* `BOLT_VERBOSE`: Enable verbose output in the Bolt plan.
* `BOLT_TRACE`: Enable error stack traces from the Bolt plan.
* `BOLT_STREAM`: Enable streaming output from Bolt scripts and commands.

### Run `vagrant up`

Finally:

```
vagrant up
```

The process takes nearly 30 minutes on a fast system with only 2 agents defined,
so be prepared to wait.

Once the Console has started, it will be available at http://localhost:6468/.

### Manual configuration

The remaining configuration is manual.

1. Retrieve the registration token from http://localhost:6468/#infrastructure-client.
2. Configure the `simp_scanner` Puppet module.
3. Run `puppet agent -t` on all nodes.
4. Run `simp-scanner scan` on all nodes.

## Using the Bolt plan on real servers

The Bolt plan that is used to build out the environment in Vagrant *should* work with real systems, although this **has not been tested**.

1. Set the `SIMP_LICENSE_KEY` as described above.
2. On the SIMP server, set the `role` fact to `puppet`.
    This can be done with the following commands:
    ```
    mkdir -pv /etc/facter/facts.d
    echo role=puppet > /etc/facter/facts.d/role.txt
    ```
    If the name of the SIMP server starts with `puppet`, this step can be skipped.
3. On the SIMP Console server, set the `role` fact to `console`.
    This can be done with the following commands:
    ```
    mkdir -pv /etc/facter/facts.d
    echo role=console > /etc/facter/facts.d/role.txt
    ```
    If the name of the SIMP Console server starts with `console`, this step can be skipped.
4. Run the Bolt plan with the targets specified on the command line:
    ```
    bolt plan run simp_ee -t simpserver,consoleserver,agent1,agent2
    ```

## Known issues

### Windows agents with Fedora's `vagrant` package

Windows agents will not work with the Fedora-supplied `vagrant` package.  The
required `winrm` gem is not available and some of its dependencies will not
resolve with `vagrant plugin install`.

Either omit the Windows agents from the `SIMP_AGENTS` environment variable or
switch to Hashicorp's `vagrant` package.

### CentOS 8 agents with VirtualBox

CentOS 8 agents seem to hang when running under VirtualBox.

Either omit `centos8` agents from the `SIMP_AGENTS` environment variable or
switch to another virtualization provider.
