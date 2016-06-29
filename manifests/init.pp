# == Class: homebrew
#
# Install HomeBrew  for Mac OS/X (http://brew.sh/) as a Puppet package provider
#
# Do not forget to download the command line tools for XCode from Apple
# and store them on a local repository.
# Caveat: You need an Apple ID to do that!
#
# === Parameters
#
# Document parameters here.
#
# [*xcode_cli_source*]
#   Contains the URL where this module can find the XCode CLI package.
#   Default: undef
#
# [*xcode_cli_version*]
#   Contains the version of the desired Xcode CLI package.
#   Default: undef
#
# [*user*]
#   Tells which user will own the Homebrew installation.
#   It is highly encouraged to choose a user different than the default.
#   Default: root
#
# [*group*]
#   Tells which group will own the Homebrew installation.
#   You should add users to this group later on
#   if you want them to be allowed to install brews.
#   Defaults: brew
#
# [*update_every*]
#   Tells how often a brew update should be run.
#   if 'default', it will be run every day at 02:07, local time.
#   if 'never', it will never run...
#   otherwise, MM:HH:dd:mm:wd is expected. Where:
#     - MM is the minute
#     - HH is the hour
#     - dd is the day of the month
#     - mm is the month
#     - wd is the week day
#   See https://docs.puppetlabs.com/references/latest/type.html#cron and
#   man crontab for a full explanation of time representations.
#   Note we do not support multi-values at the moment ([2, 4], e.g.).
#   Default: 'default'
#
# [*install_package*]
#   Tells if packages should be installed by searching the hiera database.
#   Default: true
#
# === Examples
#
#  include homebrew
#
#  To install for a given user:
#
#  class { 'homebrew':
#    user  => gildas,
#    group => brew,
#  }
#
#  class { 'homebrew':
#    user         => gildas,
#    group        => brew,
#    update_every => '01:*/6'
#  }
#
# === Authors
#
# Author Name <gildas@breizh.org>
#
# === Copyright
#
# Copyright 2014, Gildas CHERRUEL.
#
class homebrew (
  $brewpath          = '/usr/local/homebrew',
  $brewurl           = 'https://github.com/mxcl/homebrew/tarball/master',
  $xcode_cli_source  = undef,
  $xcode_cli_version = undef,
  $user              = root,
  $group             = brew,
  $update_every      = 'default',
  $install_packages  = true
)
{

  if ($::operatingsystem != 'Darwin')
  {
    err('This Module works on Mac OS/X only!')
    fail("Unsupported OS: ${::operatingsystem}")
  }
  if (versioncmp($::macosx_productversion_major, '10.7') < 0)
  {
    err('This Module works on Mac OS/X Lion or more recent only!')
    fail("Unsupported OS version: ${::macosx_productversion_major}")
  }

  if ($xcode_cli_source) {
    $xcode_cli_install = url_parse($xcode_cli_source, 'filename')

    if ($::has_compiler != true or ($xcode_cli_version and $::xcodeversion != $xcode_cli_version))
    {
      package {$xcode_cli_install:
        ensure   => present,
        provider => pkgdmg,
        source   => $xcode_cli_source,
      }
    }
  }

  $homebrew_directories = [
     "${brewpath}/bin",
     "${brewpath}/etc",
     "${brewpath}/include",
     "${brewpath}/lib",
     "${brewpath}/lib/pkgconfig",
     "${brewpath}/Library",
     "${brewpath}/sbin",
     "${brewpath}/share",
     "${brewpath}/var",
     "${brewpath}/var/log",
     "${brewpath}/share/locale",
     "${brewpath}/share/man",
     "${brewpath}/share/man/man1",
     "${brewpath}/share/man/man2",
     "${brewpath}/share/man/man3",
     "${brewpath}/share/man/man4",
     "${brewpath}/share/man/man5",
     "${brewpath}/share/man/man6",
     "${brewpath}/share/man/man7",
     "${brewpath}/share/man/man8",
     "${brewpath}/share/info",
     "${brewpath}/share/doc",
     "${brewpath}/share/aclocal",
     "${brewpath}/temp",
     '/Library/Caches/Homebrew',
     '/Library/Logs/Homebrew',
  ]

  # Ensure the group, user, and home directory exist
  ensure_resource('group', $group, {'ensure' => 'present'})
  if $user != 'root' {
    ensure_resource('user', $user, {'ensure' => 'present', 'shell' => '/bin/bash'})
    ensure_resource('file', "/Users/${user}", {'ensure' => 'directory', 'owner' => $user, 'group' => $group, 'mode' => '0755', 'require' => [User[$user], Group[$group]]})
  }
  #if defined(File[$brewpath]) == false{
  file {$brewpath:
     ensure  => directory,
     owner   => $homebrew::user,
     group   => $homebrew::group,
     mode    => '0775',
     require => Group[$group],
  }
  #} ->

  file {$homebrew_directories:
    ensure  => directory,
    owner   => $homebrew::user,
    group   => $homebrew::group,
    mode    => '0775',
    require => File[$brewpath],
  }-> 

  exec {'install-homebrew':
    cwd       => $brewpath,
    command   => "su ${homebrew::user} -c 'bash -o pipefail -c \"curl -skSfL ${brewurl} | tar xz -m --strip 1\"'",
    path      => ['/usr/bin','/bin','/usr/local/bin','/usr/sbin','/sbin'],
    creates   => "${brewpath}/bin/brew",
    logoutput => on_failure,
    timeout   => 0,
    require   => File['/etc/profile.d/homebrew.sh'],
    notify    => Exec['brew update'],
  }
  exec{'brew update'
     command     => "su ${homebrew::user} -c 'brew update'":
     path        => ['/usr/bin','/bin','/usr/local/bin','/usr/sbin','/sbin',"${brewpath}/bin"],
     logoutput   => on_failure,
     refreshonly => true,
  }

  if (! defined(File['/etc/profile.d']))
  {
    file {'/etc/profile.d':
      ensure => directory
    }
  }

  file {'/etc/profile.d/homebrew.sh':
    owner   => root,
    group   => wheel,
    mode    => '0775',
    source  => "puppet:///modules/${module_name}/homebrew.sh",
    require => File['/etc/profile.d'],
  }

  if ($::has_compiler != true and $xcode_cli_source)
  {
    Package[$xcode_cli_install] -> Exec['install-homebrew']
  }

  file { "${brewpath}/bin/brew":
    owner   => $homebrew::user,
    group   => $homebrew::group,
    mode    => '0775',
    require => Exec['install-homebrew'],
  }

  case $update_every
  {
    'default', true, present:
    { # By default we update brew every day at 02:07A (odd time on purpose)
      $cron_ensure    = present
      $cron_minute    = '7'
      $cron_hour      = '2'
      $cron_monthday  = absent
      $cron_month     = absent
      $cron_weekday   = absent
    }
    'never', false, absent:
    {
      $cron_ensure    = absent
      $cron_minute    = absent
      $cron_hour      = absent
      $cron_monthday  = absent
      $cron_month     = absent
      $cron_weekday   = absent
    }
    default:
    {
      $frequencies    = split($update_every, ':')
      $cron_ensure    = present
      $cron_minute    = $frequencies[0]
      $cron_hour      = size($frequencies) ? { /(1|2|3|4)/ => $frequencies[1], default => absent }
      $cron_monthday  = size($frequencies) ? { /(2|3|4)/   => $frequencies[2], default => absent }
      $cron_month     = size($frequencies) ? { /(3|4)/     => $frequencies[3], default => absent }
      $cron_weekday   = size($frequencies) ? { /4/         => $frequencies[4], default => absent }
    }
  }
  $env = [
     'HOMEBREW_CACHE=/Library/Caches/Homebrew',
     'HOMEBREW_LOGS=/Library/Logs/Homebrew/',
     "PATH=/usr/bin:/bin:/usr/local/bin:/usr/sbin:/sbin:${brewpath}/bin"
  ]
  cron {'cron-update-brew':
    ensure      => $cron_ensure,
    command     => "${brewpath}/bin/brew update 2>&1 >> /Library/Logs/Homebrew/cron-update-brew.log",
    environment => $env,
    user        => root,
    minute      => $cron_minute,
    hour        => $cron_hour,
    monthday    => $cron_monthday,
    month       => $cron_month,
    weekday     => $cron_weekday,
    require     => Exec['install-homebrew'],
  }

  if $install_packages {
    include homebrew::packages
  }

}
