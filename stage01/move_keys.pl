#!/usr/bin/perl

my $last_stage = `tail -n 1 ../status/test.stat`;

my $stage = 0;

if( $last_stage =~ /STAGE(\d+)/ ){
	$stage = $1;
};

if( $stage > 0 ){
	$stage++;
	my $next_stage = sprintf("%02d", $stage);
	if( -e "./mykey0.priv" ){
		system("cp ./mykey0.priv ../stage$next_stage/.");
	};

	if( -e "./mykey1.priv" ){
        	system("cp ./mykey1.priv ../stage$next_stage/.");
	};
};
exit(0);

