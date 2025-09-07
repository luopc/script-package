
#!/bin/bash
# 接收所有传入的参数作为需要远程执行的命令
COMMAND=$*
# 主机信息文件，记录着每台主机的IP、用户名、端口和密码
HOST_INFO=../../../../backup/src/main/resources/host.info
# 遍历host.info文件中的每一行，提取IP地址
for IP in $(awk '/^[^#]/{print $1}' $HOST_INFO); do
    # 根据IP地址从host.info文件中提取对应的用户名
    #$(awk -v ip=$IP 'ip==$1{print $2}' $HOST_INFO)
    USER=${USER:-uat}
    # 根据IP地址从host.info文件中提取对应的端口号
    PORT=$(awk -v ip=$IP 'ip==$1{print $3}' $HOST_INFO)
    # 根据IP地址从host.info文件中提取对应的密码
    PASS=$(awk -v ip=$IP 'ip==$1{print $4}' $HOST_INFO)
    # 使用expect工具自动进行SSH连接，并发送命令
    expect -c "
       spawn ssh -p $PORT $USER@$IP
       expect {
          \"(yes/no)\" {send \"yes\r\"; exp_continue}
          \"password:\" {send \"$PASS\r\"; exp_continue}
          \"$USER@*\" {send \"$COMMAND\r exit\r\"; exp_continue}
       }
    "
    # 输出分隔线，方便查看每台主机的执行结果
    echo "-------------------"
done
