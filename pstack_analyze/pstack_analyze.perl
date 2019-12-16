#!/usr/bin/perl
# 该脚本用于将pstack打印出来的堆栈信息去重
# 参数：pstack输出的文件
# 注意：比较时会自动忽略函数参数
# Author: leapking, 2018-11-28
# Move to: https://github.com/dbcheck/pstack

# 统计出现的次数
# 在数组第一行后面追加"@Same:$num"用于记录重复次数
sub updateSameCnt
{
	my ($aref) = @_;
	chomp(@{$aref}[0]);

	if (@{$aref}[0] !~ /\@Same:/)
	{
		@{$aref}[0] = "@{$aref}[0] \@Same:1\n";
		return (0);
	}

	my @words = split(/\@Same:/, @{$aref}[0]);
	$words[1] = $words[1] + 1;
	@{$aref}[0] = "$words[0]\@Same:$words[1]\n";
}

# 比较两个堆栈信息是否一样
# 传递数组时，必须传递对数组的引用。注意对引用的使用。
sub diffStack
{
	my ($aref1, $aref2) = @_;

	if (@{$aref1} != @{$aref2})
	{
		return(1);
	}

	for($i = 1; $i < @{$aref1}; $i = $i + 1)
	{
		# 将(后面都内容都去掉后比较，忽略函数参数
		my @stack1 = split(/\(/, @{$aref1}[$i]);
		my @stack2 = split(/\(/, @{$aref2}[$i]);

                $stack1[0] =~ s/0x.* in/ in/; ##5  0x0000000000002000 in ?? () 去掉in前的地址信息
                $stack2[0] =~ s/0x.* in/ in/;

		if($stack1[0] cmp $stack2[0])
		{
			return(1);
		}
	}
	return(0);
}

# 对堆栈进行去重
sub uniqAllStack()
{
	my $match = 1;

	print "========== Uniq All Stack ==========\n";
	foreach my $stackId (sort {$a<=>$b} keys %StackHash)
	{
		$match = 1;
		foreach my $uniqId (keys %UniqStack)
		{
			if (diffStack(\@{$StackHash{$stackId}}, \@{$UniqStack{$uniqId}}) == 0)
			{
				#print "$stackId match as $uniqId\n";
				updateSameCnt(\@{$UniqStack{$uniqId}});
				$match = 0;
				last;
			}
		}

		if ($match == 1)
		{
			$UniqStack{$stackId} = $StackHash{$stackId};
			updateSameCnt(\@{$UniqStack{$stackId}});
		}
	}

	# output uniq stack
	foreach my $uniqId (sort {$a<=>$b} keys %UniqStack)
	{
		print "\n";
		print @{$UniqStack{$uniqId}};
	}
	print "\nuniq    stack num: ".keys(%UniqStack)."\n";
}

# 查询含某个关键字的堆栈
sub searchAllStack
{
	my $grep = 0;
	my $keyword = "";
	my $matchCnt = 0;

	if (@ARGV < 2) {
		return(1);
	} elsif (@ARGV == 2) {
		$keyword = $ARGV[1];
	} elsif (@ARGV > 2) {
		if ($ARGV[1] == "-v") {
			$grep = 1;
			$keyword = $ARGV[2];
		} else {
			return(1);
		}
	}

	print "\n========== Search All Stack: grep $ARGV[1] $ARGV[2] ==========\n";
	foreach my $uniqId (sort {$a<=>$b} keys %UniqStack)
	{
		if ($grep == 0) {
			if (grep(/$keyword/, @{$UniqStack{$uniqId}}))
			{
				print "\n";
				print @{$UniqStack{$uniqId}};
				my @words = split(/\@Same:/, @{$UniqStack{$uniqId}}[0]);
				$matchCnt = $matchCnt + $words[1];
			}
		} else {
			if (!grep(/$keyword/, @{$UniqStack{$uniqId}})) {
				print "\n";
				print @{$UniqStack{$uniqId}};
				my @words = split(/\@Same:/, @{$UniqStack{$uniqId}}[0]);
				$matchCnt = $matchCnt + $words[1];
			}
		}
	}
	print "\nmatched stack num: $matchCnt\n";
}

# Main
(my $Program = $0) =~ s!.*/(.*)!$1!;
if (@ARGV == 0 || ! -e "$ARGV[0]")
{
	print "$Program - uniq stackfile or search stack from uniq result\n\n";
	print "Usage: perl $Program {StackFile} [-v] [keyword]\n";
	print "Report bug to leapking\@126.com\n";
	exit(0);
}

# 0. remove some unexpected newline
$file = "$ARGV[0]";
$tmpfile = "$file.tmp";
open(filein, $file) or die "failed to open \"$file\": $!";
open(fileout, ">$tmpfile") or die "failed to open \"$tmpfile\": $!";
while(<filein>)
{
	chomp($_);
	my $line = $_;

	$line =~ s/^\s+/ /g;
	if (length($line) == 0 || $line =~ /^#[0-9]+|Thread/) #判断何时需要换行
	{
		print fileout "\n";
	}
	print fileout "$line";
}
close(filein);
close(fileout);

# 1. Load all stack info to %StackHash
$StackCnt = 0;
$StackId = 0;
%StackHash = ();
open(filein, $tmpfile) or die "failed to open \"$tmpfile\": $!";
while(<filein>)
{
	chomp($_);
	my $line = $_;

	if (length($line) == 0 || $line !~ /^Thread|#[0-9]+/) #判断何时需要换行
	{
		next;
	}

	if (/^Thread [0-9]+/)
	{
		my @words = split(' ', $line);
		$StackId = $words[1].".$StackCnt";	#将"Thread 24616"中的24616取到StackId，并作为hash key
		$StackCnt = $StackCnt + 1;
	}

	push(@{$StackHash{$StackId}}, "$line\n");	#将hash值$StackHash{$StackId}直接作为数组使用，将每一行存入数组
}
close(filein);
unlink($tmpfile);

# 2. dispatch
%UniqStack = ();
uniqAllStack();

searchAllStack();

print "all     stack num: ".keys(%StackHash)."\n";
