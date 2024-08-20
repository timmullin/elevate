package Elevate::Components::PackageRestore;

=encoding utf-8

=head1 NAME

Elevate::Components::PackageRestore

Handle restoring packages that get removed during elevate

Before leapp:
    Detect which packages in our list are installed and
    store our findings.

After leapp:
    Reinstall any packages detected pre-leapp

=cut

use cPstrict;

use Elevate::StageFile ();

use Cpanel::Pkgr ();

use File::Copy    ();
use Log::Log4perl qw(:easy);

use parent qw{Elevate::Components::Base};

#
# Set as a function for unit testing
#
sub _get_packages_to_check () {
    return qw{
      net-snmp
    };
}

#
# Set as a function for unit testing
#
sub _get_files_to_restore ($package) {

    my $package_files_to_restore = {
        'net-snmp' => [
            qw{
              /etc/snmp/snmpd.conf
              /etc/snmp/snmptrapd.conf
            }
        ],
    };

    if ( exists $package_files_to_restore->{$package} ) {
        return $package_files_to_restore->{$package};
    }
    else {
        return [];
    }
}

sub pre_leapp ($self) {

    my @package_list = _get_packages_to_check();
    my @installed_packages;

    foreach my $package (@package_list) {
        if ( Cpanel::Pkgr::is_installed($package) ) {
            push @installed_packages, $package;
        }
    }

    Elevate::StageFile::update_stage_file(
        {
            'packages_to_restore' => \@installed_packages,
        }
    );

    return;
}

sub post_leapp ($self) {

    my $packages = Elevate::StageFile::read_stage_file('packages_to_restore');
    return unless defined $packages and ref $packages eq 'ARRAY';

    foreach my $package (@$packages) {

        $self->yum->install($package);

        my $restore_files = _get_files_to_restore($package);

        foreach my $restore_file (@$restore_files) {
            my $backup_file = $restore_file . '.rpmsave';

            if ( -e $backup_file ) {
                File::Copy::copy( $backup_file, $restore_file )
                  or WARN("Failed to copy $backup_file to $restore_file: $!");
            }
        }
    }

    return;
}

1;
