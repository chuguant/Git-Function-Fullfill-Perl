#!/usr/bin/perl -w

use File::Copy;
use File::Compare;
use Digest::MD5 qw(md5_hex);

#define the file and the name will be used
$Root_Dir = ".legit";
$Index_Dir = ".legit/index";
$Log = ".legit/log";
$Snapshot_Dir = ".legit/snapshots";
$Branch_Dir = ".legit/branch";

# init function, if file has existed, return error
# init file to be used
sub init {
    #check if the .legit file exist
    if (-d $Root_Dir) {
        die "legit.pl: error: .legit already exists\n";
    }
    mkdir($Root_Dir);
    mkdir($Index_Dir);
	mkdir($Snapshot_Dir);
    mkdir($Branch_Dir);
    print "Initialized empty legit repository in .legit\n";
}

sub main {
    @args = @ARGV;   
    # if no argument, give instruction
    if (scalar @args == 0) {
        usage_Instruction();
    } 
    # init function implementation
	if ($args[0] eq "init") {
		init(@args);
	}
    else {
		# Checks if .legit folder exist
        # examine the argument to check the function
		if (!(-d "$Root_Dir")) {
			die "legit.pl: error: no .legit directory containing legit repository exists\n";
		}
		if ($args[0] eq "add") {
            shift @args;
            add(@args);
		}
        elsif ($args[0] eq "commit") {
			commit(@args);
		}
        elsif ($args[0] eq "log") {
			logs();
		}
        elsif ($args[0] eq "show") {
			show(@args);
		}
        elsif ($args[0] eq "rm") {
            shift @args;
            rm(@args);
        } 
        elsif ($args[0] eq "status") {
            status();
        }
        # help function 
        elsif ($args[0] eq "help") {
            usage_Instruction();
        }
	}
}

# call main function
main();

# add function, to add the current file to index directory
sub add {
    # check if the root folder exist
    if (! -d $Root_Dir) {
        die "legit.pl: error: no .legit directory containing legit repository exists\n";
    }
    @files = @_;
	foreach  $file(@files) {
        # check if file exist
        if (! -e $file && ! -e "$Index_Dir/$file") {
            die "legit.pl: error: can not open '$file'\n";
        } 
        # if file deleted in working directory, delete it in index directory
        elsif (! -e $file && -e "$Index_Dir/$file") {
            unlink "$Index_Dir/$file";
        }
        # copies each of the current files into the index directory
        if ($file =~ /^[a-zA-Z0-9]{1,}[\.\-\_]{0,}/) {
            copy($file,"$Index_Dir/$file");
        }
	}
}

# commit function, to create a snapshop of the current index directory to a specified snapshot directory
# Save copy of all files in index to the snapshot directory
sub commit {
    # if argument less than one, throw exception
    ($#args > 1) or die "usage: legit.pl commit [-a] -m commit-message\n";
    $m = 1;
    # check the input -m
    while ($args[$m] ne "-m") {
        $m++; 
    }
    # check if message exists.
    $#args > $m and substr($args[$m+1], 0, 1) ne "-" or die "usage: legit.pl commit [-a] -m commit-message\n";
    $i = 1;
    $update_flg = 0;
    # check the input -a, update the file in index directory
    while ($i <= $#args) {
        $args[$i] eq "-a" and $update_flg = 1 and last;
        $i++;    
    }
    if ($update_flg) {
        # get all the file in index directory
        foreach $index_File (glob "$Index_Dir/*") {   
            # match indexfile
            $index_File =~ m/^\.legit\/index\/(.+)$/g;
            $file = $1;
            open F, "<", $file or die;
            # file array
            @array = <F>;
            close F;
            # update the file from working directory to index directory
            open F, ">", "$index_File" or die;
            while (scalar @array > 0) {
                $line = shift @array;
                print F "$line";
            }
            close F;
        }
    }
    # commit flag
    $commit_flg = 1;
    # Load Current Commit Number
    @files = glob "$Snapshot_Dir/*";
    my $number_of_file = @files;
    # when no file in snapshop directory
    if ($number_of_file == 0) {
        $next_Commit_Num = 0;
    }
    # when there are files in snapshop directory
    elsif ($number_of_file > 0) {
        $next_Commit_Num = Load_Cur_Commit()+1
    }
    # commit message
    $commit_message = $args[$m+1];
    # Save a copy of all files in the index to the snapshop directory or print "Nothing to commit" if index hasn't changed compared to prev commit
    # if not the first commit
    if ($next_Commit_Num > 0) {
        $commit_flg = 0;
        # recent commit num
        $cur_Commit_Num = $next_Commit_Num-1;
        foreach $index_File (glob "$Index_Dir/*") {
            $index_File =~ m/^\.legit\/index\/(.+)$/g;
            $file = $1;
            # compare file, if not the same, flg = 1
            if (!Compare_File("$index_File", "$Snapshot_Dir/$cur_Commit_Num/$file")) {
                $commit_flg = 1;
                last;
            }
        }
        # account for removed files here
        if ($commit_flg == 0) {
            foreach $commit_File (glob "$Snapshot_Dir/$cur_Commit_Num/*") {
                $commit_File =~ m/^\.legit\/snapshots\/$cur_Commit_Num\/(.+)$/g;
                $file = $1;
                # if file not in the index file
                if (!-e "$Index_Dir/$file") {
                    $commit_flg = 1;
                    last;
                } 
            }
        }
        # write log to log file
        open $log, ">>", "$Log" or die;
    } 
    else {
        # the first line in log file
        open $log, ">", "$Log" or die;
    }
    # when commit flag is on
    if ($commit_flg) {
        # create snapshot sub-directory
        mkdir "$Snapshot_Dir/$next_Commit_Num";
        foreach $index_File (glob "$Index_Dir/*") {
            # matcg index file
            $index_File =~ m/^\.legit\/index\/(.+)$/g;
            $file = $1;
            # add index file to snapshop directory
            open F, "<", "$index_File" or die;
            while ( $line = <F> ) {
                push @array, $line;
            }
            close F;
            open F, ">", "$Snapshot_Dir/$next_Commit_Num/$file" or die;
            while ( scalar @array > 0 ) {
                $line = shift @array;
                print F "$line";
            }
            close F;
            $commit_flg = 0;
        }
        print $log "$next_Commit_Num $commit_message\n";
        print "Committed as commit $next_Commit_Num\n";
    } else {
        die "nothing to commit\n";
    }
    close $log;
}

sub logs {
	# If there are no commits, print error message
	if (!(-e "$Root_Dir/log")) {
		die "legit.pl: error: your repository does not have any commits yet\n";
	}
    # To print the line in log file in reverse way
    open FILE, "<", "$Root_Dir/log" or die "Error finding the commit history file";
    my @lines = reverse <FILE>;
    foreach my $line (@lines) {
        print $line;
    }   
    close FILE;
}

sub show {
    @args = @_;
    $file_Path = "";
    # get current commit number
    $cur_Commit_Num = Load_Cur_Commit();

	#Split apart the <commit>:<filename> argument
    $arg2 = $args[1];
	$arg2 =~ /(.*):(.*)/;
    $commit_Name = $1;
    $file_Name = $2;

	#Check all cases of invalid input
	#Where no commit is given
	if($commit_Name eq ""){
		#Check the file_Name supplied is valid
		if (($file_Name eq "") || ($file_Name !~ /^[a-zA-Z0-9]/)) {
			die "legit.pl: error: invalid file_Name '$file_Name'\n";
		}
        else {
            #Check that the file exists in index
			if (!(-e "$Index_Dir/$file_Name")) {
				die "legit.pl: error: '$file_Name' not found in index\n";
			}
            else {
                #File does exist so set filepath
				$file_Path = "$Index_Dir/$file_Name";
			}
		}
	}
    else {
		#Check the commit number is valid
		if ($commit_Name > $cur_Commit_Num) {
			die "legit.pl: error: unknown commit '$commit_Name'\n";
		}
        else {
			#Checks the file_Name supplied is valid
			if (($file_Name eq "") || ($file_Name !~ /^[a-zA-Z0-9]/)) {
				die "legit.pl: error: invalid file_Name '$file_Name'\n";
			}
            else {
                #Check the file exists in the commit
				if (!(-e "$Snapshot_Dir/$commit_Name/$file_Name")) {
				    die "legit.pl: error: '$file_Name' not found in commit $commit_Name\n";
				} 
                else {
                    #File does exist so set the filepath of file
					$file_Path = "$Snapshot_Dir/$commit_Name/$file_Name";
				}
			}
		}
	}
	#Display the file
	open F, "<", $file_Path or die "Unable to open file. Exiting";
	print $_  while(<F>);
	close F;
}

sub rm {
    @args = @_;
    # force flag
    my $is_Force = 0;
    # cache flag
    my $is_Cache = 0;
    # dict
    my %files;
    # get current commit number
    $cur_Commit_Num = Load_Cur_Commit();
    # get current commit path
    $cur_Commit_Path = "$Snapshot_Dir/$cur_Commit_Num";

    # Cheack if argument file is forced
    if ( grep $_ eq "--force", @args ) {
        $is_Force = 1;
    }
    # Cheack if argument file is cached
    if (! grep $_ eq "--cached", @args ) {
        $is_Cache = 1;
    }
    # if file removed not forced and not cached the file dict of this item value equels 0
    foreach $item(@args) {
        if ($item ne "--force" && $item ne "--cached") {
            $file_Collect{$item} = 0;
        }
    }
    # print "is_Force ","$is_Force","is_Cache ",$is_Cache,"\n";

    # make a file dict to detect if file removed exist in index directory or commit directory
    foreach $file (keys %file_Collect) {
        #check if file exist in root folder
        if (-e $file) {
            $file_Collect{$file} += 1
        }
        #check if file exist in index folder
        if (-e "$Index_Dir/$file") {
            $file_Collect{$file} += 2
        }
        #check if file exist in snapshot folder
        if (-e "$cur_Commit_Path/$file") {
            $file_Collect{$file} += 4
        }
    }
    # if file removed is forced, then clacify the cases according to the file dict number
    if ($is_Force == 0) {
        foreach  $file (keys %file_Collect) {
            # print "num is $file_Collect{$file} \n";
            # file not in root directory
            if ($file_Collect{$file} == 1) {
                die "legit.pl: error: '$file' is not in the legit repository\n"
            } 
            # file only in index directory
            elsif ($file_Collect{$file} == 2) {
                #pass
            } 
            # file both in working directory and index directory
            elsif ($file_Collect{$file} == 3) {
                if (! Compare_File("$Index_Dir/$file", $file) || $is_Cache == 1) {
                    die "legit.pl: error: '$file' has changes staged in the index\n";
                } 
            } 
            # file only in snapshot directory
            elsif ($file_Collect{$file} == 4) {
                #pass
            } 
            # file both in working directory and snapshot directory
            elsif ($file_Collect{$file} == 5) {
                if (! Compare_File($file, "$cur_Commit_Path/$file") ) {
                    die "legit.pl: error: '$file' in repository is different to working file\n";
                }
            } 
            # file both in snapshot and index directories
            elsif ($file_Collect{$file} == 6) {
                #pass
            } 
            # file both in snapshot, index and working directories
            # compare the file in different direotories
            elsif ($file_Collect{$file} == 7 && $is_Cache == 1) {
                # file in index is different to both working file and repository
                if (! Compare_File($file, "$cur_Commit_Path/$file") && ! Compare_File("$Index_Dir/$file", "$cur_Commit_Path/$file")  && ! Compare_File("$Index_Dir/$file", $file)){
                    die "legit.pl: error: '$file' in index is different to both working file and repository\n";
                } 
                # file in repository is different to working file
                elsif (! Compare_File($file, "$cur_Commit_Path/$file") && Compare_File("$Index_Dir/$file", "$cur_Commit_Path/$file")) {
                    die "legit.pl: error: '$file' in repository is different to working file\n";
                } 
                # file has changes staged in the index
                elsif (! Compare_File("$Index_Dir/$file", "$cur_Commit_Path/$file") ){
                    die "legit.pl: error: '$file' has changes staged in the index\n";
                }
            } 
            # file in index is different to both working file and repository
            elsif ($file_Collect{$file} == 7 && $is_Cache == 0) {
                if ( ! Compare_File("$Index_Dir/$file", "$cur_Commit_Path/$file")  && ! Compare_File("$Index_Dir/$file", $file)){
                    die "legit.pl: error: '$file' in index is different to both working file and repository\n";
                } 
            }
        }
    } 
    else {
        foreach $file (keys %file_Collect) {
            # file is not in the legit repository
            if ($file_Collect{$file} == 1) {
                die "legit.pl: error: '$file' is not in the legit repository\n"
            }
            # file is not in the legit repository 
            elsif ($file_Collect{$file} == 5) {
                die "legit.pl: error: '$file' is not in the legit repository\n"
            }
        }
    }
    # delete the file in index directory and current working directory
    foreach $file (keys %file_Collect) {
        unlink "$Index_Dir/$file";
        if ($is_Cache == 1) {
            unlink $file; 
        }
    }
}

sub status {
    # define the current commit directory path
    $cur_Commit_Num = Load_Cur_Commit();
    $current_Commit_Dir = "$Snapshot_Dir/$cur_Commit_Num";

    # sort the commit directory file
    opendir  $dir, $current_Commit_Dir or die "Cannot open directory: $!\n";
    my @snap_shot = grep(/^[a-zA-Z0-9]{1,}[\.\-\_]{0,}/, readdir $dir);
    closedir $dir;
    @snap_shot = sort @snap_shot;

    # sort the index directory file
    opendir $dir, $Index_Dir or die "Cannot open directory: $!\n";
    my @index = grep(/^[a-zA-Z0-9]{1,}[\.\-\_]{0,}/, readdir $dir);
    closedir $dir;
    @index = sort @index;

    # sort the work directory file
    opendir $dir, "." or die "Cannot open directory: $!\n";
    my @work = grep(/^[a-zA-Z0-9]{1,}[\.\-\_]{0,}/,readdir $dir);
    closedir $dir;
    @work = sort @work;

    # use the dict to collect if the file in each commit, index, work directory
    my %file_Collect = ();

    # file in snapshot directory
    foreach(@snap_shot){
        $file_Collect{$_}+=1;
    }
    # file in index directory
    foreach(@index){
        $file_Collect{$_}+=2;
    }
    # file in work directory
    foreach(@work){
        $file_Collect{$_}+=4;
    }
    # in file collect dict, to classify the file according to their num in dict
    foreach $file_Name (sort keys %file_Collect) {
        print "$file_Name - ";
        # file only in snapshot directory
        if ($file_Collect{$file_Name} == 1 ) {
            print "deleted";
        } 
        # file only in index directory
        elsif ($file_Collect{$file_Name} == 2 || $file_Collect{$file_Name} == 3 ) {
            print "file deleted";
        } 
        # file only in working directory
        elsif ($file_Collect{$file_Name} == 4){
            print "untracked";
        } 
        # file both in working directory and in snapshot directory
        elsif ($file_Collect{$file_Name} == 5) {
            print "untracked";
        }
        # file both in index and working directory, but not in snapshot directory
        elsif ($file_Collect{$file_Name} == 6) {
            print "added to index";
        } 
        # if num = 7, the file exist in three files, so we need to compare
        elsif ($file_Collect{$file_Name} == 7) {
            # file in working directory is same as snapshot directory
            if (Compare_File($file_Name,"$current_Commit_Dir/$file_Name")) {
                print "same as repo";
            } 
            else {
                print "file changed, ";
                # file in working directory is different with index directory and file in snapshot directory is different with index directory
                if (! Compare_File("$current_Commit_Dir/$file_Name","$Index_Dir/$file_Name") && ! Compare_File($file_Name,"$Index_Dir/$file_Name") ) {
                    print "different changes staged for commit";
                }
                # file in working directory is same with index directory and file in snapshot directory is different with index directory 
                elsif (! Compare_File("$current_Commit_Dir/$file_Name","$Index_Dir/$file_Name") && Compare_File($file_Name,"$Index_Dir/$file_Name") ) {
                    print "changes staged for commit";
                } 
                # file in working directory is directory with index directory and file in snapshot directory is same with index directory 
                else {
                    print "changes not staged for commit";
                }
            }
        } 
        else {
            print "$file_Collect{$file_Name}";
        }
        print "\n";
    }
}

sub usage_Instruction{
	print "Usage: $0: <command> [<args>]\n\n";
	print "These are the legit commands:\n";
	print "\tinit    \tCreate an empty legit repository\n";
	print "\tadd     \tAdd file contents to the index\n";
	print "\tcommit  \tRecord changes to the repository\n";
	print "\tlog     \tShow commit log\n";
	print "\trm      \tRemove files from the current directory and from the index\n";
	print "\tstatus  \tShow the status of files in the current directory, index, and repository\n";
	print "\tbranch  \tlist, create or delete a branch\n";
	print "\tcheckout\tSwitch branches or restore current directory files\n";
	print "\tmerge   \tJoin two development histories together\n\n";
}

sub Compare_File {
    ($file1, $file2) = @_;
    # define 2 hash
    $hash1 = Digest::MD5->new;
    $hash2 = Digest::MD5->new;

    # Check file exist
    if (! -e $file1 && ! -e $file2 ) {
        return 1;
    } elsif (! -e $file1 || ! -e $file2 ) {
        return 0;
    }

    # add line in file1 to hash
    open F , "<", $file1 or die "Can't open '$file1': $!\n";
    foreach  $line (<F>) {
        $hash1->add($line);
    }
    close F;

    # add line in file2 to hash
    open F , "<", $file2 or die "Can't open '$file2': $!\n";
    foreach  $line (<F>) {
        $hash2->add($line);
    }
    close F;

    # compare hash, if same return 1, if not return 0
    if ($hash1->hexdigest eq $hash2->hexdigest ) {
        return 1;
    } else {
        return 0;
    }
}

# get the recent commit number
sub Load_Cur_Commit {
    @files = glob "$Snapshot_Dir/*";
    my $number_of_file = @files;
    # print "snapshot file num", $number_of_file, "\n";
	if (-e "$Root_Dir/log") {
        # Load Current Commit Number
        if ($number_of_file == 0) {
            return 0
        }
        else {
            open F, "<", "$Root_Dir/log" or die "Legit has become corrupted, please reinitialise it";
            $lastline = $_ while <F>;
            ($num) = $lastline =~ /(\w+)/; 
            close F;
            return $num;
        }
	}
    else {
        return 0;
    }
}