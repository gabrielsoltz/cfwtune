#!/bin/bash
########################################################################################################################
# CFWTUNE
########################################################################################################################
CFWTUNE_DESCRIPTION="Cisco Firewalls Tune (ACL Optimizer)"
CFWTUNE_VERSION="1.0"
CFWTUNE_AUTHOR="Gabriel Soltz"
CFWTUNE_CONTACT="thegaby@gmail.com"
CFWTUNE_DATE="September 2014"
CFWTUNE_GIT="https://github.com/gabrielsoltz/cfwtune"
########################################################################################################################

########################################################################################################################
# DEPENDENCIES
########################################################################################################################
type -P ipcalc >/dev/null 2>&1 || { echo >&2 " ! ERROR: Se necesita ipcalc Instalado.  Abortando..."; exit 1; }
type -P dos2unix >/dev/null 2>&1 || { echo >&2 " ! ERROR: Se necesita dos2unix Instalado.  Abortando..."; exit 1; }
type -P ruby >/dev/null 2>&1 || { echo >&2 " ! ERROR: Se necesita ruby Instalado.  Abortando..."; exit 1; }
RANGE2CIDR="deps/range2cidr.ry"
if [ ! -f $RANGE2CIDR  ]; then echo " ! ERROR: Se necesita range2cidr.py" && exit 1 ; fi
if ! [ `stat -c %A $RANGE2CIDR | sed 's/...\(.\).\+/\1/'` == "x" ]; then echo " ! ERROR: Permisos range2cidr.py" && exit 1 ; fi

########################################################################################################################
# PARAMETERS
########################################################################################################################
if [ "$#" == 0 ] || [ "$#" == 1 ] || [ "$#" -gt 2 ] ; then
	echo " ! ERROR: Uso: ./cfwtune.sh <shroute> <shrun/shtech>"
	echo " ! ERROR: Use: ./cfwtune.sh <shroute> <shrun/shtech>"
	exit 1
else
	export FILE_ROUTE="$1"
	export FILE_CONFIG="$2"
	dos2unix -q "$FILE_ROUTE"
	dos2unix -q "$FILE_CONFIG"
fi
######## Check File Route
# First Letter C or S ?
FILE_ROUTE_FIRST_LETTER=$(head -c 1 $FILE_ROUTE)
if [ ! "$FILE_ROUTE_FIRST_LETTER" == "S" ] && [ ! "$FILE_ROUTE_FIRST_LETTER" == "C" ] ; then
	echo " ! ERROR: Check Route File. I'm looking for a route."
	echo " ! ERROR: Verificar el Archivo de Ruteo. Busco una ruta."
	exit 1
fi
######## Check File Config
# First Line : Saved ?
FILE_CONFIG_FIRST_LINE=$(head -1 $FILE_CONFIG)
if [ ! "$FILE_CONFIG_FIRST_LINE" == ": Saved" ] ; then
	echo " ! ERROR: Check Config File. I'm looking for : Saved at first line."
	echo " ! ERROR: Verificar Archivo de Configuracion..."
	exit 1
fi

########################################################################################################################
# LOGGING
########################################################################################################################
DATE=$(date +%m-%d-%Y_%H-%M)Hs
FILE_OUTPUT=cfwtune-$DATE-$(basename "$FILE_CONFIG")
######## Logging Header
echo "" | tee -a $FILE_OUTPUT
echo ---------------------------------------------------------------------- | tee -a $FILE_OUTPUT
echo "CFWTUNE" | tee -a $FILE_OUTPUT
echo "$CFWTUNE_DESCRIPTION" | tee -a $FILE_OUTPUT
echo "Version: $CFWTUNE_VERSION" | tee -a $FILE_OUTPUT
echo "Author: $CFWTUNE_AUTHOR" | tee -a $FILE_OUTPUT
echo "Contact: $CFWTUNE_CONTACT" | tee -a $FILE_OUTPUT
echo "Date: $CFWTUNE_DATE" | tee -a $FILE_OUTPUT
echo "GIT/SVN: $CFWTUNE_GIT" | tee -a $FILE_OUTPUT
echo ---------------------------------------------------------------------- | tee -a $FILE_OUTPUT
echo "Configuration File: $FILE_CONFIG" | tee -a $FILE_OUTPUT
echo "Route File: $FILE_ROUTE" | tee -a $FILE_OUTPUT
echo ---------------------------------------------------------------------- | tee -a $FILE_OUTPUT
echo "" | tee -a $FILE_OUTPUT

########################################################################################################################
# TMP FILE DELETE 
########################################################################################################################
rm -f TMP-* 
rm -f OGDEPURA-*

########################################################################################################################
# NETWORKING FUNCTIONS
########################################################################################################################
function ip_to_int(){
  local IP="$1"
  local A=`echo $IP | cut -d. -f1`
  local B=`echo $IP | cut -d. -f2`
  local C=`echo $IP | cut -d. -f3`
  local D=`echo $IP | cut -d. -f4`
  local INT

  INT=`expr 256 "*" 256 "*" 256 "*" $A`
  INT=`expr 256 "*" 256 "*" $B + $INT`
  INT=`expr 256 "*" $C + $INT`
  INT=`expr $D + $INT`

  echo $INT
}

function cidr_to_mask(){
		local cidr="$1" netmask="" done=0 i=0 sum=0 cur=128
		local octets= frac=

		local octets=$((${cidr} / 8))
		local frac=$((${cidr} % 8))
		while [ ${octets} -gt 0 ]; do
				netmask="${netmask}.255"
				octets=$((${octets} - 1))
				done=$((${done} + 1))
		done

		if [ ${done} -lt 4 ]; then
				while [ ${i} -lt ${frac} ]; do
						sum=$((${sum} + ${cur}))
						cur=$((${cur} / 2))
						i=$((${i} + 1))
				done
				netmask="${netmask}.${sum}"
				done=$((${done} + 1))

				while [ ${done} -lt 4 ]; do
						netmask="${netmask}.0"
						done=$((${done} + 1))
				done
		fi

		echo "${netmask#.*}"
}

########################################################################################################################
# FUNCTION PORT NAME
########################################################################################################################
function portname_to_portnumber(){
	portname="$1"
	case $portname in
		"ftp-data" ) export portnumber=20 ;;
		"ftp" )	export portnumber=21 ;;
		"ssh" ) export portnumber=22 ;;
		"telnet" ) export portnumber=23  ;;
		"smtp" ) export portnumber=25 ;;
		"time" ) export portnumber=37 ;;
		"nameserver" ) export portnumber=42 ;;
		"whois" ) export portnumber=43 ;;
		"tacacs" ) export portnumber=49 ;;
		"domain" ) export portnumber=53 ;;
		"bootps" ) export portnumber=67 ;;
		"tftp" ) export portnumber=69 ;;
		"finger" ) export portnumber=79 ;;
		"www" ) export portnumber=80 ;;
		"https" ) export portnumber=443 ;;
		"hostname" ) export portnumber=101 ;;
		"sunrpc" ) export portnumber=111 ;;
		"ident" ) export portnumber=113 ;;
		"nntp" ) export portnumber=119 ;;
		"ntp" ) export portnumber=123 ;;
		"netbios-ns" ) export portnumber=137 ;;
		"netbios-dgm" ) export portnumber=138 ;;
		"netbios-ssn" ) export portnumber=139 ;;
		"snmp" ) export portnumber=161 ;;
		"snmptrap" ) export portnumber=162 ;;
		"biff" ) export portnumber=512 ;;
		"exec" ) export portnumber=512 ;;
		"login" ) export portnumber=513 ;;
		"who" ) export portnumber=513 ;;
		"rsh" ) export portnumber=514 ;;
		"syslog" ) export portnumber=514 ;;
		"lpd" ) export portnumber=515 ;;
		"rip" ) export portnumber=520 ;;
	esac
	echo $portnumber
}


########################################################################################################################
# OBJECT-GROUPS SUBNETTING
########################################################################################################################
echo "" | tee -a $FILE_OUTPUT
echo ---------------------------------------------------------------------- | tee -a $FILE_OUTPUT
echo "OBJECT-GROUPS SUBNETTING" | tee -a $FILE_OUTPUT
echo ---------------------------------------------------------------------- | tee -a $FILE_OUTPUT
echo "" | tee -a $FILE_OUTPUT

# FUNCION: og_parsear_resto
# PIDE:
# - FILE_OBJECTGROUP = ARCHIVO CON UN OBJECT GROUP ENTERO
# GENERA:
# - FILE_OBJECTGROUP_RESTO = RESTO DEL OBJECT GROUP (NOMBRE, DESCRIPCION, NETWORKS)
function og_parsear_resto(){
	# PIDE:
	local FILE_OBJECTGROUP="$1"
	
	# Me guardo el Resto del Grupo
	local FILE_OBJECTGROUP_RESTO=$FILE_OBJECTGROUP-RESTO ; rm -f $FILE_OBJECTGROUP_RESTO
	cat $FILE_OBJECTGROUP | grep -v host | grep -v "255.255.255.255" >> $FILE_OBJECTGROUP_RESTO
	
	echo $FILE_OBJECTGROUP_RESTO
}
	
## FUNCION: og_parsear_hosts_sort
# PIDE:
# - FILE_OBJECTGROUP = ARCHIVO CON UN OBJECT GROUP ENTERO
# GENERA:
# - FILE_OBJECTGROUP_IPS_SORT = IPS ORDENADAS
function og_parsear_hosts_sort(){
	#PIDE:
	local FILE_OBJECTGROUP="$1"
		
	# PARSEO IPS
	local FILE_OBJECTGROUP_IPS=$FILE_OBJECTGROUP-IPS ; rm -f $FILE_OBJECTGROUP_IPS
	# FORMATO HOST
	cat $FILE_OBJECTGROUP | grep host | cut -d " " -f 4  >> $FILE_OBJECTGROUP_IPS
	# FORMATO 255.255.255.255
	cat $FILE_OBJECTGROUP | grep "255.255.255.255" | cut -d " " -f 3  >> $FILE_OBJECTGROUP_IPS
	
	# ORDENO LAS IPS
	local FILE_OBJECTGROUP_IPS_SORT=$FILE_OBJECTGROUP_IPS-SORT ; rm -f $FILE_OBJECTGROUP_IPS_SORT
	sort -t . -k 1,1n -k 2,2n -k 3,3n -k 4,4n $FILE_OBJECTGROUP_IPS > $FILE_OBJECTGROUP_IPS_SORT
	
	# Borro FILE_OBJECTGROUP_IPS
	rm -f $FILE_OBJECTGROUP_IPS
	
	echo $FILE_OBJECTGROUP_IPS_SORT
}

## FUNCION: rangos
# PIDE: 
# - FILE_IP_SORT = IPS ORDENADAS
# GENERA:
# - FILE_RANGE = IPS EN RANGOS
function rangos(){
	# PIDE: 
	local FILE_IP_SORT=$1
	# GENERAR:
	local FILE_RANGE=$FILE_IP_SORT-RANGE
	rm -f $FILE_RANGE
	# LOCALES:
	local PREVIOUS=$(head -n 1 $FILE_IP_SORT)
	local PREVIOUS_INT=$(ip_to_int $PREVIOUS)
	local LAST=$(cat $FILE_IP_SORT | wc -l)
	local COUNT=0
	local IRANGOS=0	

	# Genero Array RANGOS
	while read LINE ; 
	do
		LINE_INT=$(ip_to_int $LINE)
		# PRIMERA IP
		if (( COUNT == 0 )) ; then
			FIRST=$LINE
			FIRST_INT=$(ip_to_int $FIRST)
			((PREVIOUS_INT--))
		fi
		# BUSCO RANGOS
		if (( LINE_INT != PREVIOUS_INT + 1 )) ; then
			if (( FIRST_INT == PREVIOUS_INT )); then
				# Es una unica IP (FIRST)
				RANGOS[$IRANGOS]=$FIRST-$FIRST
			else
				# Es un Rango (FIRST - PREVIOUS)
				RANGOS[$IRANGOS]=$FIRST-$PREVIOUS
			fi
			FIRST=$LINE
			FIRST_INT=$(ip_to_int $FIRST)
		fi
		PREVIOUS=$LINE
		PREVIOUS_INT=$(ip_to_int $PREVIOUS)
		((COUNT++))
		((IRANGOS++))
		# ULTIMO RANGO
		if (( COUNT == LAST )) ; then
			PREVIOUS_INT=$(ip_to_int $PREVIOUS)
			if (( FIRST_INT == PREVIOUS_INT )); then
			# Es una unica IP (FIRST)
				RANGOS[$IRANGOS]=$FIRST-$FIRST
			else
			# Es un Rango (FIRST - PREVIOUS)
				RANGOS[$IRANGOS]=$FIRST-$PREVIOUS
			fi
		fi
	done < $FILE_IP_SORT
	
	# Escribo Array en Archivo
	for index in ${!RANGOS[*]}
	do
		echo "${RANGOS[$index]}" >> $FILE_RANGE
	done
	
	echo $FILE_RANGE
}

## FUNCION: subnet
# PIDE: 
# - FIRST = PRIMERA IP DEL RANGO
# - LAST = ULTIMA IP DEL RANGO
# GENERA:
# - FILE_SUBNET = IPS SUBNETEADAS
function subnet(){
	#PIDE:
	local IP_FIRST=$1
	local IP_LAST=$2
	local FILE_RANGE=$3
	#LOCALES:
	local CIDR=($(./$RANGE2CIDR $IP_FIRST $IP_LAST))
	#GENERA:
	FILE_SUBNET="$FILE_RANGE-SUBNET"
	FILE_NOSUBNET="$FILE_SUBNET-NO"
	#CODIGO:
	for ix in ${!CIDR[*]}
	do
		MASK=$(echo "${CIDR[$ix]}" | cut -d "/" -f 2)
		HOST=$(echo "${CIDR[$ix]}" | cut -d "/" -f 1)
		if (( MASK	 == 32 )) ; then
			echo $HOST >> $FILE_NOSUBNET
		else
			NETMASK=$(cidr_to_mask $MASK)
			echo $HOST $NETMASK >> $FILE_SUBNET
		fi
	done
	# SI NO ENCONTRE NADA
	if [ ! -f $FILE_SUBNET ]; then
		touch $FILE_SUBNET
	fi
	if [ ! -f $FILE_NOSUBNET ]; then
		touch $FILE_NOSUBNET
	fi
	#DEVUELVO
	echo $FILE_SUBNET
}

# LEO ARCHIVO DE CONFIGURACION EN BUSCA DE OBJETOS Y GENERO UN ARCHIVO POR CADA OBJETO
ILINE=1
OGLINE=1
while read LINE
do
	if echo $LINE | grep -q 'object-group network' ; then
		OGNAME=$(echo $LINE | cut -d " " -f 3)
		OGLINE=$ILINE
		echo "$LINE" > "OGDEPURA-$OGNAME"
	fi
	if [ $ILINE -gt $OGLINE ] && [[ "$LINE" == *"network-object"* ]]; then
		echo " $LINE" >> "OGDEPURA-$OGNAME"
	fi
	((ILINE++))
done < $FILE_CONFIG

# POR CADA ARCHIVO PROCESO EL SUBNETEO
TOTAL_LINES_OBJECTGROUPS_SUBNETTING=0
for i in `ls | grep OGDEPURA`
do
		## ME QUEDO EL NOMBRE DEL ARCHIVO CON EL GRUPO
		FILE_OB="$i"
		# MUESTRO RESTO DEL GRUPO
		OGRESTO=$(og_parsear_resto $FILE_OB)
		cat $OGRESTO | grep -v network-object | tee -a $FILE_OUTPUT
		## CHEQUEO QUE HAYA HOSTS EN EL GRUPO
		if [ ! $(cat $FILE_OB | grep -v -f $OGRESTO | wc -l) == 0 ]; then
			## SUBNETTING HOSTS
			HOSTSSORT=$(og_parsear_hosts_sort $FILE_OB)
			OBTENGORANGOS=$(rangos "$HOSTSSORT")
			TOTALRANGOS=$(cat "$OBTENGORANGOS" | wc -l)
			for (( IRANGO=1; IRANGO<=$TOTALRANGOS; IRANGO++ ))
			do
				FIRST=$(cat $OBTENGORANGOS | sed -n "$IRANGO"p | cut -d "-" -f 1)
				LAST=$(cat $OBTENGORANGOS | sed -n "$IRANGO"p | cut -d "-" -f 2)
				SUBNET=$(subnet $FIRST $LAST $OBTENGORANGOS)
			done
			cat $SUBNET | sed 's/^/ network-object /' | tee -a $FILE_OUTPUT
			# MUESTRO ELIMINAR
			grep -v -w -f $SUBNET-NO $FILE_OB | grep -v -f $OGRESTO | sed 's/^/ no/' | tee -a $FILE_OUTPUT
			# TESTEO .255
			# CUENTO LINEAS
			TOTALELIMINAR=$(grep -v -w -f $SUBNET-NO $FILE_OB | grep -v -f $OGRESTO | sed 's/^/ no/' | wc -l)
			TOTALAGREGAR=$(cat $SUBNET | wc -l)
			TOTALGANADASXGRUPO=`expr $TOTALELIMINAR - $TOTALAGREGAR`
			TOTAL_LINES_OBJECTGROUPS_SUBNETTING=`expr $TOTAL_LINES_OBJECTGROUPS_SUBNETTING + $TOTALGANADASXGRUPO`
			# ELIMINO ARCHIVOS CREADOS
			rm -f $HOSTSSORT $OBTENGORANGOS $SUBNET $SUBNET-NO
		fi
		## BORRO EL ARCHIVO CON EL GRUPO
		echo "" | tee -a $FILE_OUTPUT
        rm -f $FILE_OB $OGRESTO
done

# MUESTRO TOTAL DE LINEAS GANADAS
echo "" | tee -a $FILE_OUTPUT
echo "TOTAL DE LINEAS GANADAS POR SUBNETEO DE OBJECT-GROUPS: $TOTAL_LINES_OBJECTGROUPS_SUBNETTING" | tee -a $FILE_OUTPUT
echo "TOTAL LINES WON BY OBJECT-GROUPS SUBNETTING: $TOTAL_LINES_OBJECTGROUPS_SUBNETTING" | tee -a $FILE_OUTPUT

########################################################################################################################
# OBJECT-GROUPS DEPURATE (UNUSED)
########################################################################################################################
echo "" | tee -a $FILE_OUTPUT
echo ---------------------------------------------------------------------- | tee -a $FILE_OUTPUT
echo "OBJECT-GROUPS DUMMIES (UNUSED) / OBJECT-GROUPS NO UTILIZADOS" | tee -a $FILE_OUTPUT
echo ---------------------------------------------------------------------- | tee -a $FILE_OUTPUT
echo ""| tee -a $FILE_OUTPUT

TOTAL_LINES_OBJECTGROUPS_UNUSED=0
while read line_a
do
	# CHEQUEO GRUPOS TIPO NETWORK
	if echo $line_a | grep -q 'object-group network' ; then
		OGNAME=$(echo $line_a | cut -d " " -f 3)
		CONFIG_OGNAME=$(cat $FILE_CONFIG | grep $OGNAME | grep -v "object-group network")
		if [[ -z "$CONFIG_OGNAME" ]] ; then
			echo no $line_a | tee -a $FILE_OUTPUT
			((TOTAL_LINES_OBJECTGROUPS_UNUSED++))
		fi
	fi
	# CHEQUEO GRUPOS TIPO SERVICE
	if echo $line_a | grep -q 'object-group service' ; then
		OGNAME=$(echo $line_a | cut -d " " -f 3)
		CONFIG_OGNAME=$(cat $FILE_CONFIG | grep $OGNAME | grep -v "object-group service")
		if [[ -z "$CONFIG_OGNAME" ]] ; then
			echo no $line_a | tee -a $FILE_OUTPUT
			((TOTAL_LINES_OBJECTGROUPS_UNUSED++))
		fi
	fi
done < $FILE_CONFIG

# MUESTRO TOTAL DE GRUPOS A ELIMINAR
echo "" | tee -a $FILE_OUTPUT
echo "TOTAL DE LINEAS GANADAS POR OBJECT-GROUPS SIN USO: $TOTAL_LINES_OBJECTGROUPS_UNUSED" | tee -a $FILE_OUTPUT
echo "TOTAL LINES WON BY OBJECT-GROUPS DUMMIES (UNUSED): $TOTAL_LINES_OBJECTGROUPS_UNUSED" | tee -a $FILE_OUTPUT

########################################################################################################################
# ACL MISSAPLIED / ACL MAL APLICADAS
########################################################################################################################
echo ---------------------------------------------------------------------- | tee -a $FILE_OUTPUT
echo " ACLS MISSAPLIED / ACLS MAL APLICADAS" | tee -a $FILE_OUTPUT
echo ---------------------------------------------------------------------- | tee -a $FILE_OUTPUT

######## Reconozco Interfaces
echo "" | tee -a $FILE_OUTPUT
echo " RECONOCIENDO INTERFACES:" | tee -a $FILE_OUTPUT
index=0
while read line
do
        INT=$(echo $line | awk '{ print $NF }')
        INTS[$index]="$INT"
        index=$(($index+1))

done < $FILE_ROUTE

######## Las vuelvo unicas
INTS=(`for R in "${INTS[@]}" ; do echo "$R" ; done | sort -du`)
for R in "${INTS[@]}" ; do echo " $R" ; done

# RECONOCER RUTEOS
echo "" | tee -a $FILE_OUTPUT
echo " RECONOCIENDO RUTEOS:" | tee -a $FILE_OUTPUT

for index in ${!INTS[*]}
do
	subred=0
	while read line
	do
		if echo $line | grep -wq "${INTS[$index]}" ; then
			((subred++))
			IP=$(echo $line | grep -w ${INTS[$index]} | cut -d " " -f 2)
			MASK=$(echo $line | grep -w ${INTS[$index]} | cut -d " " -f 3)
			PREFIX=$(ipcalc -sp $IP $MASK | cut -d "=" -f 2)
			BROADCAST=$(ipcalc -sb $IP $MASK | cut -d "=" -f 2)
			IP_INT=$(ip_to_int $IP)
			BROADCAST_INT=$(ip_to_int $BROADCAST)
			#Debug
			#echo " $subred-$IP_INT:$BROADCAST_INT" | tee -a TMP-INT-${INTS[$index]}
			echo " $subred-$IP_INT:$BROADCAST_INT" >> TMP-INT-${INTS[$index]}
		fi
	done < $FILE_ROUTE
	#Debug
	#echo REDES=$subred | tee -a TMP-INT-${INTS[$index]}
	echo REDES=$subred >> TMP-INT-${INTS[$index]}
	echo " ${INTS[$index]} --> $subred" | tee -a $FILE_OUTPUT
done

####### Funcion Chequear Ruteo
function chequear_ruteo()
{
	local ORIGEN="$1"
	local INT="$2"
	ISROUTEOK=0

	REDES=$(grep "REDES=" TMP-INT-$INT | cut -d "=" -f 2)
	ORIGEN_INT=$(ip_to_int $ORIGEN)

	for (( ix=1; ix<=$REDES; ix++ ))
	do
		DESDE=$(grep " $ix"- TMP-INT-$INT | cut -d "-" -f 2 | cut -d ":" -f 1)
		HASTA=$(grep " $ix"- TMP-INT-$INT | cut -d "-" -f 2 | cut -d ":" -f 2)
		if [ "$ORIGEN_INT" -ge "$DESDE" ] && [ "$HASTA" -ge "$ORIGEN_INT" ] ; then
				ISROUTEOK=1
		fi
	done
	echo $ISROUTEOK
}

####### Analizar ACLS

echo "" | tee -a $FILE_OUTPUT
echo " ANALIZANDO ACLS:" | tee -a $FILE_OUTPUT
echo ""
echo "                       DO THE MAGIC !!!!! :-)"
echo "" | tee -a $FILE_OUTPUT

TOTAL_LINES_ACLS_MISSAPLIED=0

for index in ${!INTS[*]}
do
	echo "" | tee -a $FILE_OUTPUT
	echo " Buscando ACL para Interface ${INTS[$index]}..." | tee -a $FILE_OUTPUT
	ACL=$(cat $FILE_CONFIG | grep access-group | grep -e "in interface ${INTS[$index]}"$ | cut -d " " -f 2)
	if [[ -z "$ACL" ]]; then
		echo " ERROR !" | tee -a $FILE_OUTPUT
		echo "" | tee -a $FILE_OUTPUT
	else
		echo " ACL: $ACL" | tee -a $FILE_OUTPUT
		echo "" | tee -a $FILE_OUTPUT
		echo " Verificando ACLS ..." | tee -a $FILE_OUTPUT
		echo "" | tee -a $FILE_OUTPUT
		while read line
		do
			if echo $line | grep -q "access-list $ACL extended" ; then
				# Solo si la regla tiene un origen host
				if echo "$line" | grep -q "tcp host" || \
				echo "$line" | grep -q "udp host" || \
				echo "$line" | grep -q "ip host" || \
				echo "$line" | grep -q "icmp host"; then
					ORIGEN=$(echo $line | cut -d " " -f 7)
					# Verifico que es una IP
					if echo $ORIGEN | grep -q -Eo '\b((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\.|$)){4}\b' ; then
						CHECK=$(chequear_ruteo $ORIGEN ${INTS[$index]})
						if [ ! "$CHECK" == "1" ] ; then
								echo no $line | tee -a $FILE_OUTPUT
								((TOTAL_LINES_ACLS_MISSAPLIED++))
						fi
					fi
				fi
			fi
		done < $FILE_CONFIG
	fi
done

# BORRO ARCHIVOS TEMPORALES
rm -f TMP-INT-*

# MUESTRO TOTAL DE ACLS A BORRAR
echo "" | tee -a $FILE_OUTPUT
echo "TOTAL DE LINEAS GANADAS POR ACLS MAL APLICADAS: $TOTAL_LINES_ACLS_MISSAPLIED" | tee -a $FILE_OUTPUT
echo "TOTAL LINES WON BY ACLS MISSAPLIED: $TOTAL_LINES_ACLS_MISSAPLIED" | tee -a $FILE_OUTPUT

########################################################################################################################
# ACL Without Apply / ACL Sin Aplicar
########################################################################################################################
echo ---------------------------------------------------------------------- | tee -a $FILE_OUTPUT
echo " ACLS DUMMIES / ACLS SIN APLICAR" | tee -a $FILE_OUTPUT
echo ---------------------------------------------------------------------- | tee -a $FILE_OUTPUT
echo "" | tee -a $FILE_OUTPUT

# RECONOZCO ACLS
index=0
while read line
do
	if echo $line | grep -q "access-list" ; then
		if echo $line | grep -q "extended" ; then
			ACL=$(echo $line | cut -d " " -f 2)
			ACLS[$index]="$ACL"
			index=$(($index+1))
		fi
	fi
done < $FILE_CONFIG

# VUELVO ACL UNICAS
ACLS=(`for R in "${ACLS[@]}" ; do echo "$R" ; done | sort -du`)

# CUENTO ACLS A ELIMINAR
TOTAL_LINES_ACLS_NOAPPLY=0

# CHEQUEOS
for R in "${ACLS[@]}"
do 
	echo ACL: $R | tee -a $FILE_OUTPUT
	# CHEQUEO ACCES-GROUP
	if 	[[ -z $(cat $FILE_CONFIG | grep "access-group $R ") ]]; then
		echo " NO SE ENCONTRO ACCESS-GROUP !" | tee -a $FILE_OUTPUT
		cat $FILE_CONFIG | grep $R | sed 's/^/ no  /' | tee -a $FILE_OUTPUT
		TOTAL_LINES_ACLS_NOAPPLY=$(($TOTAL_LINES_ACLS_NOAPPLY+$(cat $FILE_CONFIG | grep $R | wc -l)))
		echo "" | tee -a $FILE_OUTPUT
	else
		echo " Ok" | tee -a $FILE_OUTPUT
	fi
	echo "" | tee -a $FILE_OUTPUT
done 

# MUESTRO TOTAL DE LINEAS GANADAS
echo "" | tee -a $FILE_OUTPUT
echo "TOTAL DE LINEAS GANADAS POR ACLS SIN APLICAR: $TOTAL_LINES_ACLS_NOAPPLY" | tee -a $FILE_OUTPUT
echo "TOTAL LINES WON BY ACLS WITHOUT APPLY: $TOTAL_LINES_ACLS_NOAPPLY" | tee -a $FILE_OUTPUT

########################################################################################################################
# ACLS SHADOWS (DUPLICATE)
########################################################################################################################
echo ---------------------------------------------------------------------- | tee -a $FILE_OUTPUT
echo " ACLS SHADOWS (DUPLICATE)" | tee -a $FILE_OUTPUT
echo ---------------------------------------------------------------------- | tee -a $FILE_OUTPUT
echo "" | tee -a $FILE_OUTPUT

# CONTAR SHADOWS
TOTAL_LINES_ACLS_SHADOWS=0

# SHADOW BY DESTINATION NETWORK OR ANY, WITH EQ
## BUSCO ACLS CON DESTINO = RED, LUEGO BUSCO TODAS LAS QUE TIENEN MISMO ORIGEN, PUERTO Y PROTOCOLO, Y EL DESTINO ES UN HOST
## TAMBIEN BUSCO ACLS CON DESTINO ANY Y HAGO LO MISMO.

echo " SHADOWS BY DESTINATION HOST, DESTINATION NETWORK OR DESTINATION ANY, WITH EQ" | tee -a $FILE_OUTPUT
echo " SHADOWS POR DESTINO HOST, DESTINO NETWORK O DESTINO ANY, CON EQ" | tee -a $FILE_OUTPUT
echo "" | tee -a $FILE_OUTPUT
for R in "${ACLS[@]}"
do 
	FILE_TEMP=TMP-SHADOW-$R
	FILE_TEMP_FILTER=$FILE_TEMP-FILTER
	cat $FILE_CONFIG | grep "access-list $R " > $FILE_TEMP
	# CUENTO LAS LINEAS, SOLO MATCHEO SI ES POSTERIOR.
	LINE_NUMBER_ACL_SHADOW_DESTINATION=0
	while read line_acl
	do
		((LINE_NUMBER_ACL_SHADOW_DESTINATION++))
		if echo $line_acl | grep -q " eq " ; then
			DESTINO_IP=$(echo $line_acl | rev | cut -d" " -f 4 | rev)
			DESTINO_MASK=$(echo $line_acl | rev | cut -d" " -f 3 | rev)
			HASSHADOW=0
			# VERIFICO QUE ES DESTINO NETWORK (IP + MASK)
			if (echo "$DESTINO_IP" | grep -q -Eo '\b((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\.|$)){4}\b') && \
			 (echo "$DESTINO_MASK" | grep -q -Eo '\b((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\.|$)){4}\b'); then
				# ANALIZO DESTINO (DESDE, HASTA)
				BROADCAST=$(ipcalc -sb $DESTINO_IP $DESTINO_MASK | cut -d "=" -f 2)
				IP_INT=$(ip_to_int $DESTINO_IP)
				BROADCAST_INT=$(ip_to_int $BROADCAST)
				# ANALIZO PUERTO, PROTO Y ORIGEN
				PUERTO=$(echo $line_acl | awk '{ print $NF }')
				PROTO=$(echo $line_acl | rev | cut -d" " -f 7 | rev)
				ORIGEN="$(echo $line_acl | rev | cut -d" " -f 6 | rev) $(echo $line_acl | rev | cut -d" " -f 5 | rev)"
				# ANALIZO ACCION
				ACTION=$(echo $line_acl | rev | cut -d" " -f 8 | rev)
				# ARMO FILE, DESDE LA ACL ENCONTRADA, LO ANTERIOR NO IMPORTA.
				tail -n +$LINE_NUMBER_ACL_SHADOW_DESTINATION $FILE_TEMP > $FILE_TEMP_FILTER
				# BUSCO TODAS LAS ACLS QUE TIENE MISMO: PUERTO, PROTO Y ORIGEN, Y EL DESTINO ES UN HOST
				while read line_acl_filter
				do
					if echo $line_acl_filter | grep -qv "$line_acl" ; then
						PUERTO_FILTER=$(echo $line_acl_filter | awk '{ print $NF }')
						PROTO_FILTER=$(echo $line_acl_filter | rev | cut -d" " -f 7 | rev)
						ACTION_FILTER=$(echo $line_acl_filter | rev | cut -d" " -f 8 | rev)
						ORIGEN_FILTER="$(echo $line_acl_filter | rev | cut -d" " -f 6 | rev) $(echo $line_acl_filter | rev | cut -d" " -f 5 | rev)"
						DESTINO_IP_FILTER=$(echo $line_acl_filter | rev | cut -d" " -f 4 | rev)
						DESTINO_MASK_FILTER=$(echo $line_acl_filter | rev | cut -d" " -f 3 | rev)
						if [ "$PUERTO_FILTER" = "$PUERTO" ] && [ "$PROTO_FILTER" = "$PROTO" ] && [ "$ORIGEN_FILTER" = "$ORIGEN" ] && [ "$ACTION_FILTER" = "$ACTION" ] && [ "$DESTINO_IP_FILTER" = "host" ]; then
							DESTINO_MASK_FILTER_TO_INT=$(ip_to_int $DESTINO_MASK_FILTER)
							if [ "$DESTINO_MASK_FILTER_TO_INT" -ge "$IP_INT" ] && [ "$BROADCAST_INT" -ge "$DESTINO_MASK_FILTER_TO_INT" ] ; then
								HASSHADOW=1
								echo "no $line_acl_filter" | tee -a $FILE_OUTPUT
								((TOTAL_LINES_ACLS_SHADOWS++))
							fi
						fi						
					fi		
				done < $FILE_TEMP_FILTER
				# MUESTRO ACL SI HAY FLAG
				if [ "$HASSHADOW" = "1" ]; then
					echo " > ACL: $line_acl" | tee -a $FILE_OUTPUT
					echo "" | tee -a $FILE_OUTPUT					
				fi
			fi
			# VERIFICO QUE ES DESTINO ANY			
			if  [ "$DESTINO_MASK" = "any" ]; then
				# ANALIZO PUERTO, PROTO Y ORIGEN
				PUERTO=$(echo $line_acl | awk '{ print $NF }')
				PROTO=$(echo $line_acl | rev | cut -d" " -f 6 | rev)
				ORIGEN="$(echo $line_acl | rev | cut -d" " -f 5 | rev) $(echo $line_acl | rev | cut -d" " -f 4 | rev)"
				ACTION=$(echo $line_acl | rev | cut -d" " -f 7 | rev)
				# ARMO FILE, DESDE LA ACL ENCONTRADA, LO ANTERIOR NO IMPORTA.
				tail -n +$LINE_NUMBER_ACL_SHADOW_DESTINATION $FILE_TEMP > $FILE_TEMP_FILTER
				# BUSCO TODAS LAS ACLS QUE TIENE MISMO PUERTO, ORIGEN Y PROTO
				while read line_acl_filter
				do
					if echo $line_acl_filter | grep -qv "$line_acl" ; then
						PUERTO_FILTER=$(echo $line_acl_filter | awk '{ print $NF }')
						PROTO_FILTER=$(echo $line_acl_filter | rev | cut -d" " -f 7 | rev)
						ACTION_FILTER=$(echo $line_acl_filter | rev | cut -d" " -f 8 | rev)						
						ORIGEN_FILTER="$(echo $line_acl_filter | rev | cut -d" " -f 6 | rev) $(echo $line_acl_filter | rev | cut -d" " -f 5 | rev)"
						if [ "$PUERTO_FILTER" = "$PUERTO" ] && [ "$PROTO_FILTER" = "$PROTO" ] && [ "$ORIGEN_FILTER" = "$ORIGEN" ] && [ "$ACTION_FILTER" = "$ACTION" ] ; then
							HASSHADOW=1
							echo "no $line_acl_filter" | tee -a $FILE_OUTPUT
							((TOTAL_LINES_ACLS_SHADOWS++))							
						fi
					fi
				done < $FILE_TEMP_FILTER
				# MUESTRO ACL SI HAY FLAG
				if [ "$HASSHADOW" = "1" ]; then
					echo " > ACL: $line_acl" | tee -a $FILE_OUTPUT
					echo "" | tee -a $FILE_OUTPUT
				fi
			fi
		fi
	done < $FILE_TEMP
	rm -f $FILE_TEMP $FILE_TEMP_FILTER
done

# SHADOW BY SOURCE NETWORK OR ANY, WITH EQ
## BUSCO ACLS CON ORIGEN = RED, LUEGO BUSCO TODAS LAS QUE TIENEN MISMO DESTINO, PUERTO Y PROTOCOLO, Y EL ORIGEN ES UN HOST
## ANALIZO SI ESE HOST, ESTA COMPRENDIDO EN LA RED.
## TAMBIEN BUSCO ACLS CON ORIGEN ANY Y HAGO LO MISMO.

echo " SHADOW BY SOURCE HOST, SOURCE NETWORK OR SOURCE ANY, WITH EQ" | tee -a $FILE_OUTPUT
echo " SHADOW POR ORIGEN HOST, ORIGEN NETWORK O ORIGEN ANY, CON EQ" | tee -a $FILE_OUTPUT
echo "" | tee -a $FILE_OUTPUT
for R in "${ACLS[@]}"
do 
	FILE_TEMP=TMP-SHADOW-$R
	FILE_TEMP_FILTER=$FILE_TEMP-FILTER
	cat $FILE_CONFIG | grep "access-list $R " > $FILE_TEMP
	# CUENTO LAS LINEAS, SOLO MATCHEO SI ES POSTERIOR.
	LINE_NUMBER_ACL_SHADOW_SOURCE=0
	while read line_acl
	do
		((LINE_NUMBER_ACL_SHADOW_SOURCE++))
		if echo $line_acl | grep -q " eq " ; then
			ORIGEN_IP=$(echo $line_acl | rev | cut -d" " -f 6 | rev)
			ORIGEN_MASK=$(echo $line_acl | rev | cut -d" " -f 5 | rev)
			HASSHADOW=0
			# VERIFICO QUE ES NETWORK (IP + MASK)
			if (echo "$ORIGEN_IP" | grep -q -Eo '\b((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\.|$)){4}\b') && \
			 (echo "$ORIGEN_MASK" | grep -q -Eo '\b((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\.|$)){4}\b'); then
				# ANALIZO ORIGEN (DESDE, HASTA)
				BROADCAST=$(ipcalc -sb $ORIGEN_IP $ORIGEN_MASK | cut -d "=" -f 2)
				IP_INT=$(ip_to_int $ORIGEN_IP)
				BROADCAST_INT=$(ip_to_int $BROADCAST)
				# ANALIZO PUERTO, PROTO Y DESTINO
				PUERTO=$(echo $line_acl | awk '{ print $NF }')
				PROTO=$(echo $line_acl | rev | cut -d" " -f 7 | rev)
				DESTINO="$(echo $line_acl | rev | cut -d" " -f 4 | rev) $(echo $line_acl | rev | cut -d" " -f 3 | rev)"
				# ANALIZO ACTION
				ACTION=$(echo $line_acl | rev | cut -d" " -f 8 | rev)
				# ARMO FILE, DESDE LA ACL ENCONTRADA, LO ANTERIOR NO IMPORTA.
				tail -n +$LINE_NUMBER_ACL_SHADOW_SOURCE $FILE_TEMP > $FILE_TEMP_FILTER
				# BUSCO TODAS LAS ACLS QUE TIENE MISMO: PUERTO, PROTO Y DESTINO, Y EL ORIGEN ES UN HOST
				while read line_acl_filter
				do
					if echo $line_acl_filter | grep -qv "$line_acl" ; then
						PUERTO_FILTER=$(echo $line_acl_filter | awk '{ print $NF }')
						PROTO_FILTER=$(echo $line_acl_filter | rev | cut -d" " -f 7 | rev)
						ACTION_FILTER=$(echo $line_acl_filter | rev | cut -d" " -f 8 | rev)						
						DESTINO_FILTER="$(echo $line_acl_filter | rev | cut -d" " -f 4 | rev) $(echo $line_acl_filter | rev | cut -d" " -f 3 | rev)"
						ORIGEN_IP_FILTER=$(echo $line_acl_filter | rev | cut -d" " -f 6 | rev)
						ORIGEN_MASK_FILTER=$(echo $line_acl_filter | rev | cut -d" " -f 5 | rev)
						if [ "$PUERTO_FILTER" = "$PUERTO" ] && [ "$PROTO_FILTER" = "$PROTO" ] && [ "$DESTINO_FILTER" = "$DESTINO" ] && [ "$ACTION_FILTER" = "$ACTION" ] && [ "$ORIGEN_IP_FILTER" = "host" ]; then
							ORIGEN_MASK_FILTER_TO_INT=$(ip_to_int $ORIGEN_MASK_FILTER)
							if [ "$ORIGEN_MASK_FILTER_TO_INT" -ge "$IP_INT" ] && [ "$BROADCAST_INT" -ge "$ORIGEN_MASK_FILTER_TO_INT" ] ; then
								HASSHADOW=1
								echo "no $line_acl_filter" | tee -a $FILE_OUTPUT
								((TOTAL_LINES_ACLS_SHADOWS++))
							fi
						fi
					fi
				done < $FILE_TEMP_FILTER
				# MUESTRO ACL SI HAY FLAG
				if [ "$HASSHADOW" = "1" ]; then
					echo " > ACL: $line_acl" | tee -a $FILE_OUTPUT
					echo "" | tee -a $FILE_OUTPUT
				fi				
			fi
			# VERIFICO QUE ES ORIGEN ANY
			if  [ "$ORIGEN_MASK" = "any" ]; then
				# ANALIZO PUERTO, PROTO Y DESTINO
				PUERTO=$(echo $line_acl | awk '{ print $NF }')
				PROTO=$(echo $line_acl | rev | cut -d" " -f 6 | rev)
				DESTINO="$(echo $line_acl | rev | cut -d" " -f 4 | rev) $(echo $line_acl | rev | cut -d" " -f 3 | rev)"
				ACTION=$(echo $line_acl | rev | cut -d" " -f 7 | rev)
				# ARMO FILE, DESDE LA ACL ENCONTRADA, LO ANTERIOR NO IMPORTA.
				tail -n +$LINE_NUMBER_ACL_SHADOW_SOURCE $FILE_TEMP > $FILE_TEMP_FILTER
				# BUSCO TODAS LAS ACLS QUE TIENE MISMO PUERTO, PROTO Y DESTINO
				while read line_acl_filter
				do
					if echo $line_acl_filter | grep -qv "$line_acl" ; then
						PUERTO_FILTER=$(echo $line_acl_filter | awk '{ print $NF }')
						PROTO_FILTER=$(echo $line_acl_filter | rev | cut -d" " -f 7 | rev)
						ACTION_FILTER=$(echo $line_acl_filter | rev | cut -d" " -f 8 | rev)
						DESTINO_FILTER="$(echo $line_acl_filter | rev | cut -d" " -f 4 | rev) $(echo $line_acl_filter | rev | cut -d" " -f 3 | rev)"
						if [ "$PUERTO_FILTER" = "$PUERTO" ] && [ "$PROTO_FILTER" = "$PROTO" ] && [ "$DESTINO_FILTER" = "$DESTINO" ] && [ "$ACTION_FILTER" = "$ACTION" ]; then
							HASSHADOW=1
							echo "no $line_acl_filter" | tee -a $FILE_OUTPUT
							((TOTAL_LINES_ACLS_SHADOWS++))
						fi
					fi
				done < $FILE_TEMP_FILTER
				# MUESTRO ACL SI HAY FLAG
				if [ "$HASSHADOW" = "1" ]; then
					echo " > ACL: $line_acl" | tee -a $FILE_OUTPUT
					echo "" | tee -a $FILE_OUTPUT
				fi
			fi
		fi
	done < $FILE_TEMP
	rm -f $FILE_TEMP $FILE_TEMP_FILTER
done

# SHADOW POR RANGO
# SHADOW BY RANGE
## BUSCO ACLS CON PUERTO EN RANGE, Y DESPUES BUSCO MISMO ORIGEN, DESTINO, PUERTO Y PROTO CON EQ QUE LO CONTENGA

echo " SHADOWS POR RANGO DE PUERTOS" | tee -a $FILE_OUTPUT
echo " SHADOWS BY RANGE PORTS" | tee -a $FILE_OUTPUT
echo "" | tee -a $FILE_OUTPUT
for R in "${ACLS[@]}"
do 
	FILE_TEMP=TMP-SHADOW-$R
	FILE_TEMP_FILTER=$FILE_TEMP-FILTER
	cat $FILE_CONFIG | grep "access-list $R " > $FILE_TEMP
	# CUENTO LAS LINEAS, SOLO MATCHEO SI ES POSTERIOR.
	LINE_NUMBER_ACL_SHADOW_RANGE=0
	while read line_acl
	do
		((LINE_ACL_SHADOW_RANGE_NUMBER++))
		if echo $line_acl | grep -q  "range " ; then
			# ANALIZO RANGO DE PUERTOS
			FIRST_PORT=$(echo $line_acl | rev | cut -d" " -f 2 | rev)
			if ! [[ "$FIRST_PORT" =~ ^-?[0-9]+$ ]]; then
				FIRST_PORT=$(portname_to_portnumber $FIRST_PORT)
			fi
			LAST_PORT=$(echo $line_acl | rev | cut -d" " -f 1 | rev)
			if ! [[ "$LAST_PORT" =~ ^-?[0-9]+$ ]]; then
				LAST_PORT=$(portname_to_portnumber $LAST_PORT)
			fi
			HASSHADOW=0
			# ANALIZO PROTO
			PROTO=$(echo $line_acl | rev | cut -d" " -f 8 | rev)
			# ANALIZO ORIGEN Y DESTINO (2 PARTES CADA UNO)
			DESTINO="$(echo $line_acl | rev | cut -d" " -f 5 | rev) $(echo $line_acl | rev | cut -d" " -f 4 | rev)"
			ORIGEN="$(echo $line_acl | rev | cut -d" " -f 7 | rev) $(echo $line_acl | rev | cut -d" " -f 6 | rev)"
			# ANALIZO ACTION
			ACTION=$(echo $line_acl | rev | cut -d" " -f 9 | rev)
			# ARMO FILE, DESDE LA ACL ENCONTRADA, LO ANTERIOR NO IMPORTA.
			tail -n +$LINE_ACL_SHADOW_RANGE_NUMBER $FILE_TEMP > $FILE_TEMP_FILTER
			# BUSCO TODAS LAS ACLS QUE TIENE MISMO ORIGEN, DESTINO Y PROTO Y PUERTO EQ (Y EL PUERTO ESTA COMPRENDIDO EN EL RANGO)
			while read line_acl_filter
			do
				if (echo $line_acl_filter | grep -qv "$line_acl") && (echo $line_acl_filter | grep -q " eq "); then
					PROTO_FILTER=$(echo $line_acl_filter | rev | cut -d" " -f 7 | rev)
					DESTINO_FILTER="$(echo $line_acl_filter | rev | cut -d" " -f 4 | rev) $(echo $line_acl_filter | rev | cut -d" " -f 3 | rev)"
					ORIGEN_FILTER="$(echo $line_acl_filter | rev | cut -d" " -f 6 | rev) $(echo $line_acl_filter | rev | cut -d" " -f 5 | rev)"
					ACTION=$(echo $line_acl_filter | rev | cut -d" " -f 8 | rev)
					PUERTO_FILTER=$(echo $line_acl_filter | awk '{ print $NF }')
					if ! [[ "$PUERTO_FILTER" =~ ^-?[0-9]+$ ]]; then
						PUERTO_FILTER=$(portname_to_portnumber $PUERTO_FILTER)
					fi
					if [ "$PROTO_FILTER" = "$PROTO" ] && [ "$DESTINO_FILTER" = "$DESTINO" ] && [ "$ORIGEN_FILTER" = "$ORIGEN" ] && [ "$ACTION_FILTER" = "$ACTION" ]; then
						if [ "$PUERTO_FILTER" -ge "$FIRST_PORT" ] && [ "$LAST_PORT" -ge "$PUERTO_FILTER" ] ; then
							HASSHADOW=1
							echo "no $line_acl_filter" | tee -a $FILE_OUTPUT
							((TOTAL_LINES_ACLS_SHADOWS++))
						fi
					fi
				fi
			done < $FILE_TEMP_FILTER
			# MUESTRO ACL SI HAY FLAG
			if [ "$HASSHADOW" = "1" ]; then
				echo " > ACL: $line_acl" | tee -a $FILE_OUTPUT
				echo "" | tee -a $FILE_OUTPUT
			fi
		fi
	done < $FILE_TEMP	
	rm -f $FILE_TEMP $FILE_TEMP_FILTER
done

# MUESTRO TOTAL DE LINEAS GANADAS
echo "" | tee -a $FILE_OUTPUT
echo "TOTAL DE LINEAS GANADAS POR ACLS SHADOW: $TOTAL_LINES_ACLS_SHADOWS" | tee -a $FILE_OUTPUT
echo "TOTAL LINES WON BY ACLS SHADOW: $TOTAL_LINES_ACLS_SHADOWS" | tee -a $FILE_OUTPUT

# TO DO: SHADOW POR DENY

########################################################################################################################
# FOOTER
########################################################################################################################
echo ---------------------------------------------------------------------- | tee -a $FILE_OUTPUT
echo "End. Count:" | tee -a $FILE_OUTPUT
echo "" | tee -a $FILE_OUTPUT
echo " 1. Object-Group Subnetting: $TOTAL_LINES_OBJECTGROUPS_SUBNETTING" | tee -a $FILE_OUTPUT
echo " 2. Object-Group Dummies (Unused): $TOTAL_LINES_OBJECTGROUPS_UNUSED" | tee -a $FILE_OUTPUT
echo " 3. ACLS Misapplied (Wrong Routing): $TOTAL_LINES_ACLS_MISSAPLIED" | tee -a $FILE_OUTPUT
echo " 4. ACLS Dummies (Unused): $TOTAL_LINES_ACLS_NOAPPLY" | tee -a $FILE_OUTPUT
echo " 5. ACLS Shadows (Duplicate): $TOTAL_LINES_ACLS_SHADOWS" | tee -a $FILE_OUTPUT
echo " --> Total Won Lines: $(($TOTAL_LINES_OBJECTGROUPS_SUBNETTING+$TOTAL_LINES_OBJECTGROUPS_UNUSED+$TOTAL_LINES_ACLS_MISSAPLIED+$TOTAL_LINES_ACLS_NOAPPLY+$TOTAL_LINES_ACLS_SHADOWS)) "
echo ---------------------------------------------------------------------- | tee -a $FILE_OUTPUT
echo "Output File: $FILE_OUTPUT"
echo "" | tee -a $FILE_OUTPUT
