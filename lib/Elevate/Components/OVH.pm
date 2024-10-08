package Elevate::Components::OVH;

=encoding utf-8

=head1 NAME

Elevate::Components::OVH

=head2 check

Ensure touch file acknowledging OVH monitoring is in place before allowing
upgrades to occur on servers with IPs in the OVH data center(s) range

=head2 pre_distro_upgrade

noop

=head2 post_distro_upgrade

noop

=cut

use cPstrict;

use Elevate::Constants;

use Cpanel::Version::Tiny ();
use Cpanel::Update::Tiers ();

use parent qw{Elevate::Components::Base};

use Log::Log4perl qw(:easy);

sub check ($self) {

    return 0 unless $self->__is_ovh();

    my $touch_file = Elevate::Constants::OVH_MONITORING_TOUCH_FILE;

    return 0 if -e $touch_file;

    my $message = <<~"EOS";
    We have detected that your server is hosted by "OVH SA" company.

    Before continuing the elevation process, you should disable the "proactive monitoring" provided by OVH.
    When using "proactive monitoring" your server could incorrectly boot in rescue mode during the elevate process.

    Once you have disabled the monitoring system (or confirm this message does not apply to you),
    please touch that file and continue the elevation pricess.

    > touch $touch_file

    You can read more about this issue:
    URL: https://github.com/cpanel/elevate/issues/176
    OVH Monitoring Documentation: https://support.us.ovhcloud.com/hc/en-us/articles/115001821044-Overview-of-OVHcloud-Monitoring-on-Dedicated-Servers
    EOS

    return $self->has_blocker($message);
}

sub __is_ovh ($self) {
    return 1 if -e q[/root/.ovhrc];

    my @ip_rules = qw{
      5.39.0.0/17
      5.135.0.0/16
      5.196.0.0/16
      8.7.244.0/24
      8.18.128.0/24
      8.18.172.0/24
      8.20.110.0/24
      8.21.41.0/24
      8.24.8.0/21
      8.26.94.0/24
      8.29.224.0/24
      8.30.208.0/21
      8.33.96.0/21
      8.33.128.0/21
      8.33.136.0/23
      15.204.0.0/16
      15.235.0.0/16
      23.92.224.0/19
      37.59.0.0/16
      37.60.48.0/20
      37.187.0.0/16
      45.92.60.0/22
      46.105.0.0/16
      46.244.32.0/20
      51.38.0.0/16
      51.68.0.0/16
      51.75.0.0/16
      51.77.0.0/16
      51.79.0.0/16
      51.81.0.0/16
      51.83.0.0/16
      51.89.0.0/16
      51.91.0.0/16
      51.161.0.0/16
      51.178.0.0/16
      51.195.0.0/16
      51.210.0.0/16
      51.222.0.0/16
      51.254.0.0/15
      54.36.0.0/14
      57.128.0.0/17
      57.128.128.0/18
      62.3.18.0/24
      66.70.128.0/17
      79.137.0.0/17
      87.98.128.0/17
      91.90.88.0/21
      91.121.0.0/16
      91.134.0.0/16
      92.222.0.0/16
      92.246.224.0/19
      94.23.0.0/16
      103.5.12.0/22
      107.189.64.0/18
      109.190.0.0/16
      135.125.0.0/16
      135.148.0.0/16
      137.74.0.0/16
      139.99.0.0/16
      141.94.0.0/15
      142.4.192.0/19
      142.44.128.0/17
      144.2.32.0/19
      144.217.0.0/16
      145.239.0.0/16
      146.59.0.0/16
      147.135.0.0/16
      148.113.0.0/18
      148.113.128.0/17
      149.56.0.0/16
      149.202.0.0/16
      151.80.0.0/16
      151.127.0.0/16
      152.228.128.0/17
      158.69.0.0/16
      162.19.0.0/16
      164.132.0.0/16
      167.114.0.0/16
      172.83.201.0/24
      176.31.0.0/16
      178.32.0.0/15
      185.12.32.0/23
      185.15.68.0/22
      185.45.160.0/22
      185.228.96.0/22
      188.165.0.0/16
      192.95.0.0/18
      192.99.0.0/16
      192.240.152.0/21
      193.31.62.0/24
      193.43.104.0/24
      193.70.0.0/17
      195.110.30.0/23
      195.246.232.0/23
      198.27.64.0/18
      198.50.128.0/17
      198.100.144.0/20
      198.244.128.0/17
      198.245.48.0/20
      209.126.71.0/24
      213.32.0.0/17
      213.186.32.0/19
      213.251.128.0/18
      217.182.0.0/16
    };

    require Net::CIDR;

    my @cidr_list;
    foreach my $rule (@ip_rules) {
        if ( Net::CIDR::cidrvalidate($rule) ) {
            @cidr_list = Net::CIDR::cidradd( $rule, @cidr_list );
        }
        else {
            WARN("Invalid CIDR rule '$rule'");
        }
    }

    require Cpanel::DIp::MainIP;
    require Cpanel::NAT;

    my $public_ip = Cpanel::NAT::get_public_ip( Cpanel::DIp::MainIP::getmainip() );
    return 1 if eval { Net::CIDR::cidrlookup( $public_ip, @cidr_list ) };

    return 0;
}

1;
