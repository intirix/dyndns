#!/usr/bin/perl

use strict;
use CGI;
use Socket;
use Net::DNS;

print( "Content-type: text/plain\n\n" );

my $config_file = "/opt/dyndns/config/dyndns.properties";

my $host_list_file = "/opt/dyndns/config/hosts.list";
my $key_file = "/opt/dyndns/config/Kdomain.key";
my @dns_servers;
my $from_email;
my $ttl = "3600";

open( IN, $config_file ) or die( "System not configured" );
while( <IN> )
{
	chomp;
	my ( $key, $value ) = split( /=/, $_, 2 );

	if ( $key eq "host_list_file" )
	{
		$host_list_file = $value;
	}
	elsif ( $key eq "key_file" )
	{
		$key_file = $value;
	}
	elsif ( $key eq "from_email" )
	{
		$from_email = $value;
	}
	elsif ( $key eq "ttl" )
	{
		$ttl = $value;
	}
	elsif ( $key eq "dns_servers" )
	{
		@dns_servers = split( /,/, $value );
	}
}
close( IN );

my $email;

my $remote_user = $ENV{ 'REMOTE_USER' };

print( "User: $remote_user\n" );


my $q = CGI->new;
my @values = $q->param('host');
my $host = $values[ 0 ];
@values = $q->param('ip');
my $new_ip = $values[ 0 ];
unless ( $new_ip )
{
	$new_ip = $q->remote_addr();
}


if ( $host )
{
	print( "host=$host\n" );

	my $hasAccess = undef;
	my $zone;

	open( IN, $host_list_file );
	while( <IN> )
	{
		chomp;
		my ( $ahost, $azone, $aemail, $userStr ) = split( /,/ );
		next unless $host eq $ahost;


		my @users = split( /;/, $userStr );
		for my $user ( @users )
		{
			if ( $user eq $remote_user )
			{
				$hasAccess = 1;
				$zone = $azone;
				$email = $aemail;
			}
		}
	}
	close( IN );

	# Verify that the user had access
	if ( $hasAccess )
	{
		my $email_body = "";


		# iterate over all the dns servers
		for my $dns_server ( @dns_servers )
		{
			# to a simple dns request to get the ip of the dns server
			my $dns_ip = inet_ntoa( inet_aton( $dns_server ) );
			print( "Checking DNS server $dns_server at $dns_ip\n" );
			# Set options in the constructor
			my $resolver = new Net::DNS::Resolver(
				nameservers => [ $dns_server ],
				recurse     => 0,
				debug       => 0
				);

			my $address;
			my $query = $resolver->send( $host );
			if ( $query )
			{
				foreach my $rr ( $query->answer )
				{
					next unless $rr->type eq "A";
					$address = $rr->address;
				}
			}

			# Check if the dns server knows about this host
			if ( $address )
			{
				# The dns server knows about this host, so
				# we should check if the IP needs updatin
				print( "    Current IP: $address\n" );
				print( "    New IP: $new_ip\n" );

				if ( $address eq $new_ip )
				{
					print( "    No change needed\n" );
				}
				else
				{
					print( "    Changing to $new_ip\n" );
					open( OUT, "| /usr/bin/nsupdate -k \"$key_file\" -v  2>&1 | sed -e 's#^#        #'" );
					print( OUT "server $dns_server\n" );
					print( OUT "zone $zone\n" );
					print( OUT "update delete ${host}. A\n" );
					print( OUT "update add ${host}. $ttl A $new_ip\n" );
					print( OUT "show\n" );
					print( OUT "send\n" );
					close( OUT );
					$email_body .= "$dns_server updated $host from $address to $new_ip\n";
				}
			}
			else
			{
				# If it doesn't, that means we need to create it
				print( "    Adding host with IP of $new_ip\n" );
				open( OUT, "| /usr/bin/nsupdate -k \"$key_file\" -v  2>&1 | sed -e 's#^#        #'" );
				print( OUT "server $dns_server\n" );
				print( OUT "zone $zone\n" );
				print( OUT "update add ${host}. $ttl A $new_ip\n" );
				print( OUT "show\n" );
				print( OUT "send\n" );
				close( OUT );

				$email_body .= "$dns_server added $host -> $new_ip\n";
			}
		}

		if ( length( $email_body ) > 0 )
		{
			print( "    Notifying $email\n" );
			open( OUT, "| /usr/sbin/sendmail $email" );
			print( OUT "Subject: $host changed IP\nTo: $email\nFrom: $from_email\n\n$email_body\n" );
			close( OUT );
		}

		print( $email_body . "\n" );
	}
	else
	{
		print( "Access denied\n" );
	}
}
else
{
	print( "No host specified\n" );
}
