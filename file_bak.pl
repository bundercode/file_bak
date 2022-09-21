#!/usr/bin/perl
use warnings;
use strict;
use File::Path qw(remove_tree);
use File::Copy::Recursive qw(rcopy);

#
# File backup script
#

my $src_path ="C:";
my $dest_path ="Z:";

my $bak_mod_times_file ="mod_times.txt";
my @src_mod_times_list;
my @src_file_list;

my $oldest_bak_date =100000000;
my $latest_bak_date =0;
my $bak_date_count =0;


main();


sub main {

	check_src_mod_times();

	# If nothing has changed, quit
	unless (@src_file_list) {die "Nothing new to back up\n";}

	# If total backups > 12, then delete oldest
	if ($bak_date_count > 12) {
		remove_tree("${oldest_bak_date}");
	}

	make_backup();
}

sub check_src_mod_times {

	my $no_bak_dates =0;
	my $latest_bak_time =0;
	my $bak_mods_line ="";	
	my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,
			$mtime,$ctime,$blksize,$blocks);

	# Move to backup directory
	chdir "${dest_path}";

	# Determine which backups are the oldest and newest
	my @backup_dates = <"*">;
	foreach my $backup_date (@backup_dates) {
		$oldest_bak_date = $backup_date if ($oldest_bak_date >= $backup_date);
		$latest_bak_date = $backup_date if ($latest_bak_date <= $backup_date);
		$bak_date_count +=1;
	}

	# Determine which directory within the newest backup date contains the latest time
	opendir LASTDATE, "${latest_bak_date}" or $no_bak_dates =1;
	foreach my $backup_time (readdir (LASTDATE)) {
		$latest_bak_time = $backup_time if (($backup_time !~ m/\D+/) 
						&& ($latest_bak_time <= $backup_time));
	}
	closedir LASTDATE;

	# Path to latest backup mod_times.txt file
	open BAKMODS, "${dest_path}/${latest_bak_date}/${latest_bak_time}/${bak_mod_times_file}" 
		or $no_bak_dates =1;

	# Get source files modified times
	opendir SRCPATH, "${src_path}";
	foreach my $src_file (readdir (SRCPATH)) {

		if ($src_file !~ m/^\./) {
			
			($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,
				$mtime,$ctime,$blksize,$blocks) =stat("$src_path/$src_file");
			push (@src_mod_times_list, "$src_file\t\t $mtime");

			if ($no_bak_dates) {
				push (@src_file_list, "$src_file");
			}
			else {
				chomp ($bak_mods_line = <BAKMODS>);
				if ($bak_mods_line ne "$src_file\t\t $mtime") {
					push (@src_file_list, "$src_file");
				}
			}
		}
	}
	closedir SRCPATH;
	close (BAKMODS);
}

sub make_backup {

	# Get current date and time
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =localtime(time);
	$year +=1900;
	$mon +=1;

	# Create directory w/ current date
	my $curr_date = sprintf ('%04s%02s%02s', ${year}, ${mon}, ${mday});
	unless (-d "${curr_date}") {
		mkdir "${curr_date}" or die $!;
	}
	chdir "${curr_date}";

	# Create directory in current date w/ current time
	my $curr_time = sprintf ('%02s%02s%02s', ${hour}, ${min}, ${sec});
	mkdir "${curr_time}" or die $!;
	chdir "${curr_time}";

	# Make new mod_times.txt
	open NEWBAKMODS, ">> $bak_mod_times_file" or die $!;
	foreach my $mod_time (@src_mod_times_list) {
		print NEWBAKMODS $mod_time . "\n";
	}
	close (NEWBAKMODS);

	# Copy source files into current time directory
	foreach my $src_file (@src_file_list) {
		rcopy("${src_path}/${src_file}","${src_file}");
	}
}
