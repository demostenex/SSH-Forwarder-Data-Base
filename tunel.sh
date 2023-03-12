#!/bin/bash

db_path="tunnel_db.sqlite"

read_tunnel_conf() {
  
  local results=$(sqlite3 $db_path "SELECT * FROM tunnels")
  
  IFS=$'\n' read -r -d '' -a lines <<< "$results"
  if [ -n "${tunnels}" ]; then
    echo ""
  else
    local tunnels=''

    for line in "${lines[@]}"; do
      tunnels+=("$line")
    done 
  fi
  
  # Pergunta ao usuário qual túnel utilizar por ordem numérica
  echo "Selecione o túnel a ser utilizado:"
  local IFS=" " 
  for i in "${!tunnels[@]}"; do
    conn_name=`echo ${tunnels[i]} | cut -d "|" -f 2`
    if [ -n "${conn_name}" ];then
      id=`echo ${tunnels[i]} | cut -d "|" -f 1`
      echo "${id}. ${conn_name}"
    fi
  done

  read opcao
  ## Verifica se a opção selecionada é válida e executa o túnel correspondente
  if [[ "$opcao" =~ ^[0-9]+$ ]] && ((opcao >= 1 && opcao <= ${#tunnels[@]})); then
    local IFS=" "
    local result=$(sqlite3 $db_path "SELECT * FROM tunnels where id = ${opcao}")
    user=`echo "${result}" | cut -d '|' -f 3`
    host=`echo "${result}" | cut -d '|' -f 4`
    ssh_opt=`echo "${result}" | cut -d '|' -f 7`
    port_args=`echo "${result}" | cut -d '|' -f 9`
    tunnel_str="ssh ${port_args} ${user}@${host} ${ssh_opt}"
    echo "A string de conexão SSH para o túnel é: ${tunnel_str}"
    eval "$tunnel_str"
  else
    echo "Opção inválida"
    read_tunnel_conf
  fi 
}

update_tunnel_conf(){
  local results=$(sqlite3 "${db_path}" "SELECT * FROM tunnels")
  
  IFS=$'\n' read -r -d '' -a lines <<< "$results"
  if [ -z "${tunnels}" ]; then
    local tunnels=''

    for line in "${lines[@]}"; do
      tunnels+=("$line")
    done 
  fi

  # Pergunta ao usuário qual túnel utilizar por ordem numérica
  echo "Selecione túnel deseja alterar:"
  local IFS=" " 
  for i in "${!tunnels[@]}"; do
    conn_name=`echo ${tunnels[i]} | cut -d "|" -f 2`
    if [ -n "${conn_name}" ];then
      id=`echo ${tunnels[i]} | cut -d "|" -f 1`
      echo "${id}. ${conn_name}"
    fi
  done

  read opcao

  echo "Selecione dado pretende alterar:"

  echo "1. Nome"
  echo "2. Usuario"
  echo "3. Endereco Remoto"
  echo "4. Porta Remota"
  echo "5. Porta Local"
  echo "6. Opções do SSH Ex: -p XXXX -o GatewayPorts=true"
  echo "7. Endereço do forwarding Ex: 127.0.0.1 localhost"

  read dado

  case $dado in
    1)
      read -p "Informe o novo nome do tunel: "  nome 
      query=`echo "UPDATE tunnels SET name='${nome}' where id=${opcao}"`
      ;;
    2)
      read -p "Informe o novo usuario do tunel: "  usuario 
      query=`echo "UPDATE tunnels SET user='${usuario}' where id=${opcao}"`
      ;;
    3)
      read -p "Informe o novo endereço remoto do tunnel: "  endereco_remoto
      query=`echo "UPDATE tunnels SET remote_host='${endereco_remoto}' where id=${opcao}"`
      ;;
    4)
      read -p "Informe a nova porta remota ou portas separadas por espaço: " porta_remota
      local result=$(sqlite3 "${db_path}" "SELECT remote_port, local_port, address_dest  FROM tunnels WHERE id=${opcao}")
      remote_port=`echo "${result}" | cut -d '|' -f 1`
      local_port=`echo "${result}" | cut -d '|' -f 2`
      address_dest=`echo "${result}" | cut -d '|' -f 3`
      echo "Portas remotas salva no banco ${remote_port} portas remotas informadas ${porta_remota}"
      read -p "Quer continuar? [S/n]" confirm
      if [ "${confirm}" = "s" ] || [ "${confirm}" = "S" ] || [ -z "${confirm}" ]
      then
        r_port=(${porta_remota// / })
        l_port=(${local_port// / })

        local port_args=""
        for i in "${!r_port[@]}"; do
          if [ -n "${l_port[i]}" ]; then
            port_args+=" -L ${l_port[i]}:${address_dest}:${r_port[i]}"
          else
            port_args+=" -L ${r_port[i]}:${address_dest}:${r_port[i]}"
          fi
        done
        query=`echo "UPDATE tunnels SET remote_port='${porta_remota}', port_args='${port_args}' where id=${opcao}"`
      else
        update_tunnel_conf
      fi
      ;;
    5)
      read -p "Informe a nova porta local ou portas separadas por espaço: " porta_local
      local result=$(sqlite3 "${db_path}" "SELECT local_port, remote_port, address_dest FROM tunnels WHERE id=${opcao}")
      local_port=`echo "${result}" | cut -d '|' -f 1`
      remote_port=`echo "${result}" | cut -d '|' -f 2`
      address_dest=`echo "${result}" | cut -d '|' -f 3`
      echo "Potas locais salva no banco ${local_port} portas remotas informadas ${porta_local}"
      read -p "Quer continuar? [S/n]" confirm
      if [ "${confirm}" = "s" ] || [ "${confirm}" = "s" ] || [ -z "${confirm}" ]
      then
        l_port=(${porta_local// / })
        r_port=(${remote_port// / })

        local port_args=""
        for i in "${!r_port[@]}"; do
          if [ -n "${l_port[i]}" ]; then
            port_args+=" -L ${l_port[i]}:${address_dest}:${r_port[i]}"
          else
            port_args+=" -L ${r_port[i]}:${address_dest}:${r_port[i]}"
          fi
        done
        query=`echo "UPDATE tunnels SET local_port='${porta_local}', port_args='${port_args}' WHERE id=${opcao}"`
      else
        update_tunnel_conf
      fi
      ;;
    6)
      read -p "Opções das configurações do ssh: " ssh_options
      query=`echo "UPDATE tunnels SET ssh_options='${ssh_options}' WHERE id=${opcao} "`
      ;;
    7)
      read -p "Digito o novo endereço para o forwarding: " address_dest
      query=`echo "UPDATE tunnels SET address_dest='${address_dest}' WHERE id=${opcao}"`
      ;;
    0)
      echo "Saindo..."
      exit 0
      ;;
    *)
      echo "Opção inválida"
      menu
      ;;
  esac

  sqlite3 "${db_path}" "${query}"
  echo "Feito a altereção no banco de dados!"
  run_tunel "${opcao}"
}

run_tunel(){
  local result=$(sqlite3 $db_path "SELECT * FROM tunnels where id = ${opcao}")
  user=`echo "${result}" | cut -d '|' -f 3`
  host=`echo "${result}" | cut -d '|' -f 4`
  ssh_opt=`echo "${result}" | cut -d '|' -f 7`
  port_args=`echo "${result}" | cut -d '|' -f 9`
  tunnel_str="ssh ${port_args} ${user}@${host} ${ssh_opt}"
  echo "A string de conexão SSH para o túnel é: ${tunnel_str}"
  eval "$tunnel_str"
}

write_tunnel_conf() {
  # Abre a conexão com o banco de dados
  
  sqlite3 "$db_path" <<EOF
  CREATE TABLE IF NOT EXISTS tunnels (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE,
    user TEXT,
    remote_host TEXT,
    remote_port TEXT,
    local_port TEXT,
    ssh_options TEXT,
    address_dest TEXT,
    port_args TEXT
  );
EOF
  # Pergunta ao usuário as informações sobre o túnel a ser adicionado
  read -p "Informe o nome do túnel: " nome
  read -p "Informe o usuário do túnel: " usuario
  read -p "Informe o endereço do servidor remoto: " endereco_remoto
  read -p "Informe a porta do serviço remoto: " porta_remota
  read -p "Informe a porta local a ser utilizada: " porta_local
  read -p "Informe opções adicionais do SSH (opcional): " ssh_options

  # Pergunta ao usuário o endereço de destino (opcional)
  read -p "Informe o endereço de destino (opcional, deixe em branco para usar o endereço do servidor remoto): " endereco_destino

  # Define o endereço de destino como o endereço do servidor remoto caso não seja especificado
  if [ -z "$endereco_destino" ]
  then
    endereco_destino="$endereco_remoto"
  fi
  
  r_port=(${porta_remota// / })
  l_port=(${porta_local// / })
  
  local port_args=""
  for i in "${!r_port[@]}"; do
    if [ -n "${l_port[i]}" ]; then
      port_args+=" -L ${l_port[i]}:${endereco_destino}:${r_port[i]}"
    else
      port_args+=" -L ${r_port[i]}:${endereco_destino}:${r_port[i]}"
    fi
  done

  # Monta a string com as informações do túnel e as opções do SSH
  tunnel_str="ssh ${port_args} ${usuario}@${endereco_remoto} ${ssh_options}"

  # Exibe a string de conexão
  echo "A string de conexão SSH para o túnel é: ${tunnel_str}"

  # Confirma se as informações estão corretas antes de salvar no banco de dados
  read -p "Deseja adicionar este túnel ao banco de dados? [S/n]: " confirm
  if [ "${confirm}" = "s" ] || [ "${confirm}" = "S" ] || [ -z "${confirm}" ]
  then
    # Insere as informações no banco de dados
    sqlite3 "$db_path" "INSERT INTO tunnels (name, user, remote_host, remote_port, local_port, ssh_options, address_dest, port_args) VALUES ('$nome', '$usuario', '$endereco_remoto', '$porta_remota', '$porta_local', '$ssh_options', '$endereco_destino', '$port_args');"
    echo "Túnel adicionado com sucesso!"
  else
    echo "Operação cancelada."
  fi
}
menu() {
  echo "Selecione uma opção:"
  echo "1. Selecionar e rodar tunel"
  echo "2. Adicionar novo túnel SSH"
  echo "3. Alterar dados de algum tunel"
  echo "0. Sair"
  read opcao

  case $opcao in
    1)
      read_tunnel_conf
      ;;
    2)
      write_tunnel_conf
      ;;
    3)
      update_tunnel_conf
      ;;
    0)
      echo "Saindo..."
      exit 0
      ;;
    *)
      echo "Opção inválida"
      menu
      ;;
  esac
}

menu
