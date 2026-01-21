
# This is CPAN.pms systemwide configuration file. This file provides
# defaults for users, and the values can be changed in a per-user
# configuration file. The user-config file is being looked for as
# /.cpan/CPAN/MyConfig.pm.

my @urllist = (
  'http://cpan.strawberryperl.com/',
  'http://www.cpan.org/',
);

if ( -d 'C:\\strawberry\\minicpan' ) {
  # If we are on fake Hotel/Airport wireless,
  # prefer the minicpan to the poisoned wireless.
  eval { require LWP::Online; };
  unless ( $@ ) {
    if ( LWP::Online::online() ) {
      push @urllist, q[file:///C:/strawberry/minicpan/];
    } else {
      unshift @urllist, q[file:///C:/strawberry/minicpan/];
    }
  }
}

$CPAN::Config = {
  applypatch                    => q[],
  auto_commit                   => q[1],
  build_cache                   => q[50],
  build_dir                     => q[C:\\strawberry\\cpan\\build],
  build_dir_reuse               => q[0],
  build_requires_install_policy => q[yes],
  bzip2                         => q[ ], #will use perl module if it is ' '
  cache_metadata                => q[1],
  check_sigs                    => q[0],
  colorize_print                => q[bold green],
  colorize_warn                 => q[bold red],
  colorize_output               => q[0],
  commandnumber_in_prompt       => q[0],
  connect_to_internet_ok        => q[1],
  cpan_home                     => q[C:\\strawberry\\cpan],
  curl                          => q[],
  ftp                           => q[C:\\Windows\\system32\\ftp.exe],
  ftp_passive                   => q[1],
  ftp_proxy                     => q[],
  getcwd                        => q[cwd],
  gpg                           => q[],
  gzip                          => q[ ], #will use perl module if it is ' '
  halt_on_failure               => q[1],
  histfile                      => q[C:\\strawberry\\cpan\\histfile],
  histsize                      => q[1000],
  http_proxy                    => q[],
  inactivity_timeout            => q[0],
  index_expire                  => q[1],
  inhibit_startup_message       => q[0],
  keep_source_where             => q[C:\\strawberry\\cpan\\sources],
  load_module_verbosity         => q[none],
  lynx                          => q[],
  make                          => q[C:\\strawberry\\c\\bin\\gmake.exe],
  make_arg                      => q[],
  make_install_arg              => q[UNINST=1],
  make_install_make_command     => q[C:\\strawberry\\c\\bin\\gmake.exe],
  makepl_arg                    => q[],
  mbuild_arg                    => q[],
  mbuild_install_arg            => q[--uninst 1],
  mbuildpl_arg                  => q[],
  ncftp                         => q[],
  ncftpget                      => q[],
  no_proxy                      => q[],
  pager                         => q[C:\\Windows\\system32\\more.COM],
  patch                         => q[C:\\strawberry\\c\\bin\\patch.exe],
  perl5lib_verbosity            => q[none],
  prefer_external_tar           => q[0],
  prefer_installer              => q[MB],
  prefs_dir                     => q[C:\\strawberry\\cpan\\prefs],
  prerequisites_policy          => q[follow],
  recommends_policy             => q[1],
  scan_cache                    => q[atstart],
  shell                         => q[C:\\Windows\\system32\\cmd.exe],
  show_unparsable_versions      => q[0],
  show_upload_date              => q[1],
  show_zero_versions            => q[0],
  suggests_policy               => q[0],
  tar                           => q[ ], #will use perl module if it is ' '
  tar_verbosity                 => q[none],
  term_is_latin                 => q[1],
  term_ornaments                => q[1],
  test_report                   => q[0],
  trust_test_report_history     => q[0],
  unzip                         => q[],
  urllist                       => \@urllist,
  use_prompt_default            => q[0],
  use_sqlite                    => q[1],
  version_timeout               => q[15],
  wget                          => q[],
  yaml_load_code                => q[0],
  yaml_module                   => q[YAML::XS],
};eval {
	require Portable;
	Portable->import('CPAN');
};


1;
__END__
