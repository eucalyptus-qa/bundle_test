#!/usr/bin/perl

$ec2timeout = 10;
$pollnum = 600;
$rc = 0;
$tmpdir = $$;

$rc = system("mkdir -p ./$tmpdir");
if ($rc) {
    print "ERROR: could not mkdir ./$tmpdir\n";
    do_exit(1);
}
$rc = system("euca-bundle-image -i ../share/windowssqueeze/windowssqueeze.img -d ./$tmpdir/");
#$rc = system("euca-bundle-image -i ./windowssqueeze.img -d $tmpdir/");
if ($rc) {
    print "ERROR: could bundle-image \n";
    do_exit(1);
}
$rc = system("euca-upload-bundle -b windowsbuk -m ./$tmpdir/windowssqueeze.img.manifest.xml");
if ($rc) {
    print "ERROR: could not upload-bundle\n";
    do_exit(1);
}
$rc = system("euca-register windowsbuk/windowssqueeze.img.manifest.xml");
if ($rc) {
    print "ERROR: could not register image\n";
    do_exit(1);
}

chomp($emi = `runat $ec2timeout euca-describe-images | grep emi | grep windowssqueeze | tail -n 1 | awk '{print \$2}'`);
if ($emi eq "") {
    print "ERROR: failed to get 'windowssqueeze' EMI\n";
    do_exit(1);
}

print "EMI:$emi\n";

$rc = system("euca-add-keypair fookey > mykey.priv");
if ($rc) {
    print "ERROR: could not add keypair\n";
    do_exit(1);
}

chomp($ida = `runat $ec2timeout euca-run-instances -k fookey $emi -t c1.medium | grep INSTANCE | awk '{print \$2}'`);
if ($ida =~ /i-.+/) {
    print "ran instance $ida\n";
} else {
    print "ERROR: failed to run 'runat $ec2timeout euca-run-instances -k fookey $emi -t c1.medium | grep INSTANCE | awk '{print \$2}''\n";
    print  "$ida\n";
    do_exit(1);
}

$done=$count=0;
while(!$done) {
    chomp($ipa=`runat $ec2timeout euca-describe-instances $ida | grep running | grep -v '0\.0\.0\.0' | awk '{print \$4}'`);
    if (($ipa =~ /\d+.\d+.\d+.\d+/) || $count > $pollnum) {
	$done++;
    }
    print "attempt $count/$pollnum\n";
    $count++;
}
if (!$ipa) {
    print "ERROR: could not get public ips\n";
    do_exit(1);
}

$done=$count=0;
while(!$done) {
    chomp($ipap=`runat $ec2timeout euca-describe-instances $ida | grep running | grep -v '0\.0\.0\.0' | awk '{print \$5}'`);
    if (($ipap =~ /\d+.\d+.\d+.\d+/) || $count > $pollnum) {
	$done++;
    }
    print "attempt $count/$pollnum\n";
    $count++;
}
if (!$ipap) {
    print "ERROR: could not get private ips\n";
    do_exit(1);
}

$rc = system("runat $ec2timeout euca-bundle-instance -b windbucket1 -p windowsimg1 -o \$EC2_ACCESS_KEY -w \$EC2_SECRET_KEY -c \"hello\" $ida");
if ($rc) {
    print "ERROR: could not run euca-bundle-instance -b windbucket1 -p windowsimg1 -o \$EC2_ACCESS_KEY -w \$EC2_SECRET_KEY -c \"hello\" $ida\n";
    do_exit(1);
}

#BUNDLEbun-4CDE0984i-4CDE0984windbucket1windowsimg1storing2010-05-20T20:22:37.855Z2010-05-20T20:22:45.69Z

$done=$count=0;
while(!$done) {
    chomp($state = `runat $ec2timeout euca-describe-bundle-tasks | grep bun- | awk '{print \$6}'`);
    if ($state eq "complete" || $count > $pollnum) {
	$done++;
    } elsif (!$state || $state eq "failed" || $state eq "canceled") {
	$done++;
	$count=$pollnum;
    }
    print "attempt $count/$pollnum\n";
    $count++;
}
if ($count > $pollnum) {
    print "ERROR: bundle-task did not complete or failed 'state=$state'\n";
    do_exit(1);
}

$rc = system("runat $ec2timeout euca-register windbucket1/windowsimg1.manifest.xml");
if ($rc) {
    print "ERROR: could not register bundled image\n";
    do_exit(1);
}

do_exit(0);

sub do_exit() {
    $ret = shift @_;

    chomp($newemi = `runat $ec2timeout euca-describe-images | grep emi | grep windowsimg1 | tail -n 1 | awk '{print \$2}'`);
    if ($newemi =~ /emi-.*/) {
	system("euca-deregister $newemi");
    }

    if ($ida =~ /i-.*/) {
	system("runat $ec2timeout euca-terminate-instances $ida");
    }
    if ($emi =~ /emi-.*/) {
	system("runat $ec2timeout euca-deregister $emi");
    }
    if (-d "./$tmpdir") {
	system("rm -rf ./$tmpdir");
    }
    system("runat $ec2timeout euca-delete-keypair fookey");
    exit($ret);
}


