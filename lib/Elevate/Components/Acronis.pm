package Elevate::Components::Acronis;

=encoding utf-8

=head1 NAME

Elevate::Components::Acronis

=head2 check

noop

=head2 pre_distro_upgrade

Find out:
Is the Acronis agent installed?
If it is, uninstall it & make a note in the stage file.
(We'll need to reinstall it after the OS upgrade.)

=head2 post_distro_upgrade

If the agent had been installed:
Re-install the agent.

=cut

use cPstrict;

use Elevate::Constants ();
use Elevate::StageFile ();

use Cpanel::Pkgr ();

use File::Slurper ();
use Log::Log4perl qw(:easy);

use parent qw{Elevate::Components::Base};

use constant ACRONIS_BACKUP_PACKAGE => 'acronis-backup-cpanel';

sub pre_distro_upgrade ($self) {

    return unless Cpanel::Pkgr::is_installed(ACRONIS_BACKUP_PACKAGE);

    $self->yum->remove(ACRONIS_BACKUP_PACKAGE);

    Elevate::StageFile::update_stage_file( { 'reinstall' => { 'acronis' => 1 } } );

    return;
}

sub post_distro_upgrade ($self) {

    return unless Elevate::StageFile::read_stage_file('reinstall')->{'acronis'};

    $self->dnf->install(ACRONIS_BACKUP_PACKAGE);

    return;
}

1;
