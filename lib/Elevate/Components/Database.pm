package Elevate::Components::Database;

=encoding utf-8

=head1 NAME

Elevate::Components::Database

Change Database provider from Sectigo to Lets Encrypt

=cut

use cPstrict;

use Elevate::Database ();

use parent qw{Elevate::Components::Base};

use Log::Log4perl qw(:easy);

sub pre_leapp ($self) {

    # We don't auto-upgrade the database if provided by cloudlinux
    return if Elevate::Database::is_database_provided_by_cloudlinux();

    # If the database version is supported on the new OS version, then no need to upgrade
    return if Elevate::Database::is_database_version_supported( Elevate::Database::get_local_database_version() );

    $self->upgrade_database_server();

    return;
}

sub post_leapp ($self) {

    # Nothing to do
    return;
}

sub upgrade_database_server ($self) {

    require Whostmgr::Mysql::Upgrade;

    my $upgrade_version = Elevate::StageFile::read_stage_file( 'mysql-version', '' );
    $upgrade_version ||= Elevate::Database::get_default_upgrade_version();

    my $upgrade_dbtype_name = Elevate::Database::get_database_type_name_from_version($upgrade_version);

    INFO("Beginning upgrade to $upgrade_dbtype_name $upgrade_version");

    my $failed_step = Whostmgr::Mysql::Upgrade::unattended_upgrade(
        {
            upgrade_type     => 'unattended_automatic',
            selected_version => $upgrade_version,
        }
    );

    if ($failed_step) {
        FATAL("FAILED to upgrade to $upgrade_dbtype_name $upgrade_version");
    }
    else {
        INFO("Finished upgrade to $upgrade_dbtype_name $upgrade_version");
    }

    return;
}

1;
