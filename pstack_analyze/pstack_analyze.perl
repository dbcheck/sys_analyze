#!/usr/bin/perl

# Describe: 该脚本用于将pstack打印出来的堆栈信息去重(通过忽略地址和函数参数信息)
# Author: leapking, 2018-11-28

# 将给定退栈信息的已出现的次数加1
## 参数：存储堆栈信息的数组
## 说明：一个堆栈信息存成一个数组，数组第一行为堆栈名称，在其后面追加"@Same:$num"用于记录重复次数
sub updateSameCnt
{
    my ($aref) = @_;
    chomp(@{$aref}[0]); #chomp用于去除换行
    my $stack_title = @{$aref}[0];

    if ($stack_title !~ /\@Same:/)  # 第一次出现，将计数置为1
    {
        $stack_title = "$stack_title \@Same:1\n";
    } else {                        # 多次出现，将计数加1
        my @split_array = split(/\@Same:/, $stack_title);
        my $stack_cnt = $split_array[1];
        $stack_cnt = $stack_cnt + 1;
        $stack_title = "$split_array[0]\@Same:$stack_cnt\n";
    }
    @{$aref}[0] = $stack_title;     # 更新堆栈标题
}

# 比较两个堆栈信息(数组)是否一样
## 参数：两个堆栈信息数组
## 说明：传递数组时，必须传递对数组的引用。注意对引用的使用。
sub diffStack
{
    my ($aref1, $aref2) = @_;

    if (@{$aref1} != @{$aref2}) #如果两个数组的长度不相等，则立刻认为不相同
    {
        return(1);
    }

    for($i = 1; $i < @{$aref1}; $i = $i + 1)
    {
        # 将(后面都内容都去掉后比较，忽略函数参数
        my @stack1 = split(/\(/, @{$aref1}[$i]);
        my @stack2 = split(/\(/, @{$aref2}[$i]);

        ##5  0x0000000000002000 in ?? () 去掉in前的地址信息
        $stack1[0] =~ s/0x.* in/ in/;
        $stack2[0] =~ s/0x.* in/ in/;

        if($stack1[0] cmp $stack2[0])
        {
            return(1);
        }
    }
    return(0);
}

# 对堆栈进行去重
## 参数1：从文件中读取的包含所有堆栈的字典
## 参数2：存储去重结果的字典
## 通过遍历已装载所有堆栈信息的字典StackHash，生成对堆栈信息去重后的字典UniqStack
sub uniqAllStack
{
    my ($aref_stacks, $aref_uniqStacks) = @_;
    my $match = 1;

    print "========== Uniq stack from `pstack` result ==========\n";
    foreach my $stackId (sort {$a<=>$b} keys %{$aref_stacks})
    {
        $match = 1;
        foreach my $uniqId (keys %{$aref_uniqStacks})
        {
            if (diffStack(\@{${$aref_stacks}{$stackId}}, \@{${$aref_uniqStacks}{$uniqId}}) == 0)
            {
                #print "$stackId match as $uniqId\n";
                updateSameCnt(\@{${$aref_uniqStacks}{$uniqId}});
                $match = 0;
                last;
            }
        }

        if ($match == 1)
        {
            ${$aref_uniqStacks}{$stackId} = ${$aref_stacks}{$stackId};
            updateSameCnt(\@{${$aref_uniqStacks}{$stackId}});
        }
    }

    # output uniq stack
    foreach my $uniqId (sort {$a<=>$b} keys %{$aref_uniqStacks})
    {
        print "\n";
        print @{${$aref_uniqStacks}{$uniqId}};
    }
}

# 查询含某个关键字的堆栈
## 参数1：包含去重后堆栈信息的字典
## 参数2：grep or egrep
## 参数3：搜索的关键字
## 说明：在已去重的堆栈信息UniqStack中搜索包含或不包含给定关键字的堆栈信息
sub searchAllStack
{
    my ($aref_uniqStacks, $grep_or_egrep, $keyword) = @_;
    my $matchCnt = 0;

    print "========== From uniq stack search: $ARGV[1] $ARGV[2] ==========\n";
    foreach my $uniqId (sort {$a<=>$b} keys %{$aref_uniqStacks})
    {
        if ($grep_or_egrep == 0) {
            if (grep(/$keyword/, @{${$aref_uniqStacks}{$uniqId}}))
            {
                print "\n";
                print @{${$aref_uniqStacks}{$uniqId}};
                my @words = split(/\@Same:/, @{${$aref_uniqStacks}{$uniqId}}[0]);
                $matchCnt = $matchCnt + $words[1];
            }
        } else {
            if (!grep(/$keyword/, @{${$aref_uniqStacks}{$uniqId}})) {
                print "\n";
                print @{${$aref_uniqStacks}{$uniqId}};
                my @words = split(/\@Same:/, @{${$aref_uniqStacks}{$uniqId}}[0]);
                $matchCnt = $matchCnt + $words[1];
            }
        }
    }
    return $matchCnt;
}

sub usage
{
    ($myProgram) = @_;
    print "$myProgram - uniq stackfile or search stack from uniq result\n\n";
    print "Usage: perl $myProgram {StackFile} [-v] [Keyword]\n";
    print "\n";
    print "    1. perl $myProgram {StackFile}              #uniq stack from file\n";
    print "    2. perl $myProgram {StackFile} {Keyword}    #uniq stack from file and search stack with Keyword\n";
    print "    3. perl $myProgram {StackFile} -v {Keyword} #uniq stack from file and except stack with Keyword\n";
    print "Report bug to leapking\@126.com\n";
    exit(0);
}

# Main
(my $Program = $0) =~ s!.*/(.*)!$1!;
if (@ARGV == 0 || ! -e "$ARGV[0]" || $ARGV[1] =~ "-h" || $ARGV[1] =~ "--help")
{
    usage($Program);
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

    if (length($line) == 0 || $line !~ /^Thread|#[0-9]+/) #空行或不是以Thread加数字开头的行，不认为是退栈内容，跳过
    {
        next;
    }

    if (/^Thread [0-9]+/)                      #以Thread加数字开头的认为是新的退栈开始
    {
        my @words = split(' ', $line);
        $StackId = $words[1].".$StackCnt";     #将"Thread 24616"中的24616取到StackId，并作为hash key
        $StackCnt = $StackCnt + 1;
    }

    push(@{$StackHash{$StackId}}, "$line\n");  #将hash值$StackHash{$StackId}直接作为数组使用，将每一行存入数组
}
close(filein);
unlink($tmpfile);

# 2. uniq stack 
%UniqStack = ();
uniqAllStack(\%StackHash, \%UniqStack);

# 3. search uniq stack
my $grep_or_egrep = 0;
my $keyword = "";
if (@ARGV >= 2) {
    if (@ARGV == 2) {
        $keyword = $ARGV[1];
    } elsif (@ARGV > 2) {
        if ($ARGV[1] == "-v") {
            $grep_or_egrep = 1;
            $keyword = $ARGV[2];
        } else {
            usage($Program);
        }
    }
    my $matchCnt = searchAllStack(\%UniqStack, $grep_or_egrep, $keyword);
    print "\n--------------------------\n";
    print "matched stack num: $matchCnt\n";
} else {
    print "\n--------------------------\n";
}
print "uniq    stack num: ".keys(%UniqStack)."\n";
print "all     stack num: ".keys(%StackHash)."\n";
