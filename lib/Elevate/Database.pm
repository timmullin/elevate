package Elevate::Database;

=encoding utf-8

=head1 NAME

Elevate::Database

Helper/Utility logic for database related tasks.

=cut

use cPstrict;

use Elevate::OS        ();
use Elevate::StageFile ();

use Cpanel::MysqlUtils::Versions ();
use Cpanel::Pkgr                 ();

use constant MYSQL_BIN => '/usr/sbin/mysqld';

sub is_database_provided_by_cloudlinux ( $use_cache = 1 ) {

    if ($use_cache) {
        my $cloudlinux_database_installed = Elevate::StageFile::read_stage_file( 'cloudlinux_database_installed', '' );

        # cloudlinux_database_installed should only ever be 1 or 0 if it is set
        # by default, read_stage_file() will return '{}', but we are telling it to send back ''
        # if cloudlinux_database_installed is not currently set
        # This allows us to be sure that the cache is set when returning it
        return $cloudlinux_database_installed if length $cloudlinux_database_installed;
    }

    if ( !Elevate::OS::provides_mysql_governor() ) {
        Elevate::StageFile::update_stage_file( { cloudlinux_database_installed => 0 } );
        return 0;
    }

    # Returns undef if database is not provided by cloudlinux
    # Do not use cache since this could be the first call from --check
    # It might be different than what is cached when called from here
    my ( $db_type, $db_version ) = Elevate::Database::get_db_info_if_provided_by_cloudlinux(0);

    return 1 if $db_type && $db_version;
    return 0;
}

sub get_db_info_if_provided_by_cloudlinux ( $use_cache = 1 ) {

    if ($use_cache) {
        my $cloudlinux_database_info = Elevate::StageFile::read_stage_file( 'cloudlinux_database_info', '' );
        return ( $cloudlinux_database_info->{db_type}, $cloudlinux_database_info->{db_version} )
          if length $cloudlinux_database_info;
    }

    my $pkg = Cpanel::Pkgr::what_provides(MYSQL_BIN);

    my ( $db_type, $db_version ) = $pkg =~ m/^cl-(mysql|mariadb|percona)([0-9]+)-server$/i;

    # cache this data so we only need to query the package manager for it once
    my $cloudlinux_database_installed = ( $db_type && $db_version ) ? 1 : 0;
    Elevate::StageFile::update_stage_file( { cloudlinux_database_installed => $cloudlinux_database_installed } );

    if ($cloudlinux_database_installed) {
        Elevate::StageFile::update_stage_file(
            {
                cloudlinux_database_info => {
                    db_type    => lc $db_type,
                    db_version => $db_version,
                }
            }
        );
    }

    return ( $db_type, $db_version );
}

sub get_database_type_name_from_version ($version) {
    return Cpanel::MariaDB::version_is_mariadb($version) ? 'MariaDB' : 'MySQL';
}

sub validate_mysql_upgrade_version ($upgrade_version) {

    require Whostmgr::Mysql::Upgrade;
    my $current_version     = Whostmgr::Mysql::Upgrade::get_current_version();
    my $current_dbtype_name = get_database_type_name_from_version($current_version);

    if ( $upgrade_version eq $current_version ) {
        return ( 0, "$current_dbtype_name is already at version $current_version" );
    }

    my @installable_versions = Cpanel::MysqlUtils::Versions::get_installable_versions_for_version($current_version);

    # The installable versions will include the current version
    @installable_versions = grep { $_ ne $current_version } @installable_versions;

    if ( !grep { $_ eq $upgrade_version } @installable_versions ) {
        my $msg = "You cannot upgrade your installation of $current_dbtype_name to version $upgrade_version.";
        if ( scalar @installable_versions ) {
            $msg .= ' You must choose one of the following: ' . join( ', ', @installable_versions ) . '.';
        }
        return ( 0, $msg );
    }

    return ( 1, '' );
}

1;
