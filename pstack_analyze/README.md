# pstack

1. pstack.sh is used to print stack of process
2. pstack_analyze.perl is used to uniq or search stack from result of pstack.sh

## GDB 使用介绍
### 1. 启动调试

前置条件：编译生成执行码时带上 -g，如果使用Makefile，通过给CFLAGS指定-g选项，否则调试时没有符号信息。

```
gdb program //最常用的用gdb启动程序，开始调试的方式
gdb program core //用gdb查看core dump文件，跟踪程序core的原因
gdb program pid //用gdb调试已经开始运行的程序，指定pid即可
gdb attach pid //用gdb调试已经开始运行的程序，指定pid即可
```

### 2. 调试命令
a. 执行命令模式, -batch选项。
比如：打印$pid进程所有线程的堆栈并退出。

```
gdb -ex "set pagination 0" -ex "thread apply all bt" -batch -p $pid
```

b. 交互模式

```
run //运行程序
continue //中断后继续运行到下一个断点
step //单步执行，进入函数
next //单步执行
return //函数未执行完，忽略未执行的语句，返回。
finish //函数执行完毕返回。
call //调用某一个函数 fun(“1234”)
(backtrace)bt //显示栈桢
bt N //显示开头N个栈桢
bt -N //显示最后N个栈桢
(frame)f N //显示第N层栈桢
list //显示源码
set directory //设置gdb的工作目录
pwd //当前的工作目录
```

c. 反复执行

```
continue N //连续执行cointiue N次，一般用于避免频繁断点
step N
next N
```

### 3. 断点

```
break 函数名 //设置断在某个函数
break 文件名:行号 //设置断在某一行
info break //查看设置的断点信息
break if condition //条件断点
break 函数名 thread 线程号 //设置断点只断某个线程，通过info threads 查看线程号
delete 断点号 断点号… //删除一个或多个断点
diable 断点号 断点号… //禁止一个或多个断点
enable 断点号 断点号… //打开一个或多个断点
command 断点号 //断点触发时，执行命令，一般用于打印变量
(gdb) command 1
Type commands for breakpoint(s) 1, one per line.
End with a line saying just “end”.

print x
end
(gdb)
```

### 4. 检测点

```
watch //为表达式（变量）expr设置一个观察点。一量表达式值有变化时，马上停住程序。
rwatch //当表达式（变量）expr被读时，停住程序。
awatch //当表达式（变量）的值被读或被写时，停住程序。
info watchpoints //列出当前所设置了的所有观察点。

经验：观察某个变量是否变化，被读或者被写，由于变量只在某一个作用域，可以获取变量的地址，然后观察。
比如：观察examined_rows变量神马时候被修改
(1). p &examined_rows,得到地址
(2). watch (ha_rows ) 0x7ffec8005e28,则可以观察这个变量的变化情况。
```

### 5. 查看变量
(1). 设置

```
set print elements N //指定打印的长度，对长字符串特别有用。
set print element 0 //输出完整的字符串
set print pretty //设置GDB打印结构的时候，每行一个成员，并且有相应的缩进，缺省是关闭的
print {type} variable

比如：
(gdb) p {ABC} 0x7fffffffe710
$2 = {val = 1.5, val2 = 10}

print xxx //打印变量
p /x xxx //16进制显示
p str@str_len //打印字符串

info locals //打印出当前函数中所有局部变量及其值。
info args //打印出当前函数的参数名及其值。
display 变量 //自动打印变量
undisplay //取消自动打印
注意：默认编译的时候，调试过程是看不见宏的值的，编译时候需要给选项。-g3
```

### 6. 内存查看

```
格式: x /nfu x 是 examine 的缩写
a. n表示要显示的内存单元的个数
b. f表示显示方式, 可取如下值
(1).x 按十六进制格式显示变量。
(2).d 按十进制格式显示变量。
(3).u 按十进制格式显示无符号整型。
(4).o 按八进制格式显示变量。
(5).t 按二进制格式显示变量。
(6).a 按十六进制格式显示变量。
(7).i 指令地址格式
(8).c 按字符格式显示变量。
(9).f 按浮点数格式显示变量。
c. u表示一个地址单元的长度
(1).b表示单字节，
(2).h表示双字节，
(3).w表示四字节，
(4).g表示八字节

比如：x/3xh buf
表示从内存地址buf读取内容，3表示三个单位，x表示按十六进制显示，h表示以双字节为一个单位。
```

### 7. 多线程调试

```
info threads //查看线程
thread thread_no //切换到线程号
thread apply all command //所有线程都执行命令打印栈桢
比如：thread apply all bt //所有线程都打印栈桢
```

(1). 线程锁

```
show scheduler-locking
set scheduler-locking on
set scheduler-locking off
默认是off，当程序继续运行的时候如果有断点，那么就把所有的线程都停下来，直到你指定某个线程继续执行(thread thread_no apply continue).
但是如果直接在当前线程执行continue的话，默认是会启动所有线程。这种模式有一种副作用，如果多个线程都断在同一个函数，这时候调试会出问题。
这个时候需要打开线程锁，但打开线程锁，意味着其它线程不能运行了。
```

(2). non-stop模式(7.0以后的版本支持)

```
set target-async 1
set pagination off
set non-stop on
gdb启动了不停模式，除了断点有关的线程会被停下来，其他线程会执行。
```

### 8. 信号量
(1).singal 发送信号
假定你的程序已将一个专用的 SIGINT（键盘输入，或CTRL-C；信号2）信号处理程序设置成采取某个清理动作，
要想测试该信号处理程序，你可以设置一个断点并使用如下命令：
（gdb） signal 2
(2).handle 拦截信号
Handle命令可控制信号的处理，他有两个参数，一个是信号名，另一个是接受到信号时该作什么。几种可能的参数是：
* nostop 接收到信号时，不要将它发送给程序，也不要停止程序。
* stop 接受到信号时停止程序的执行，从而允许程序调试；显示一条表示已接受到信号的消息（禁止使用消息除外）
* print 接受到信号时显示一条消息
* noprint 接受到信号时不要显示消息（��且隐含着不停止程序运行）
* pass 将信号发送给程序，从而允许你的程序去处理它、停止运行或采取别的动作。
* nopass 停止程序运行，但不要将信号发送给程序。
比如：
handle SIGPIPE stop print //截获SIGPIPE信号，程序停止并打印信息
handle SIGUSR1 nostop noprint //忽略SIGUSR1信号
handle SIG5 nostop pass

### 9. 生成环境使用GDB场景
内核转储(coredump)
(1).配置产生core文件
前置条件：确保系统配置的core file size足够，一般设置成unlimited
ulimit -c unlimited

配置corefile的参数：
echo 2 > /proc/sys/fs/suid_dumpable [程序中切换用户，也要产生corefile]
mkdir /tmp/corefiles
chmod 777 /tmp/corefiles
echo “/tmp/corefiles/core”>/proc/sys/kernel/core_pattern //配置core文件产生的目录为/tmp/corefiles
echo “1” > /proc/sys/kernel/core_uses_pid

注意：
a.确保配置的目录有足够的磁盘空间，否则产生core文件可能不完整。
b.对于mysqld而言，要保证正确产生core-file，需要加上–core-file，默认这个参数是不打开的。
c.kill -9 pid 是不能产生core文件的，因为SIGKILL信号不能被捕获。

(2).使用core文件
gdb /usr/mysql/bin/mysqld core.24556

(3).dump已经运行进程的状态信息
gdb attach pid
(gdb) generate-core-file
调试完毕后，通过detach命令退出。
另外，通过gcore pid 命令也可以dump core文件，生成在当前目录下。

(4).打印线程信息
pstack pid
pt-pmp -p pid
pstack和pt-pmp都可以打印线程的信息，但是pt-pmp会对同类堆栈的线程做聚合汇总，相对于pstack功能更强大，显示也更友好。

(5).altert日志
这里主要针对mysqld问题排查，mysqld异常crash后，有时候在alter日志中可以看到最后crash线程的堆栈，但是一般只有函数名或一串二进制地址，无法定位到具体是crash到哪一行，通过addr2line可以解这个问题。
比如：alter日志中记录crash时的地址是0x64bd60，通过如下命令，可以定位到具体是哪一行
addr2line -e /usr/mysql/bin/mysqld 0x64bd60
/home/admin/131_20160715135613566_11155487_code/rpm_workspace/sql/sql_parse.cc:3067

参考文档
https://www.percona.com/blog/2011/08/26/getting-mysql-core-file-on-linux/

GDB调试程序用法 http://www.linuxidc.com/Linux/2013-06/86044.htm

GDB+GDBserver无源码调试Android 动态链接库的技巧 http://www.linuxidc.com/Linux/2013-06/85936.htm

使用hello-gl2建立ndk-GDB环境(有源码和无源码调试环境) http://www.linuxidc.com/Linux/2013-06/85935.htm

在Ubuntu上用GDB调试printf源码 http://www.linuxidc.com/Linux/2013-03/80346.htm

Linux下用GDB调试可加载模块 http://www.linuxidc.com/Linux/2013-01/77969.htm

Ubuntu下使用GDB断点Go程序 http://www.linuxidc.com/Linux/2012-06/62941.htm

使用GDB命令行调试器调试C/C++程序 http://www.linuxidc.com/Linux/2014-11/109845.htm

GDB 的详细介绍：请点这里
GDB 的下载地址：请点这里

