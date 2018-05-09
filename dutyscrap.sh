#!/bin/bash
CAT_PROC=cat_procesadas.txt
CAT_XPROC=cat_por_procesar.txt
PRD_XPROC=prod_por_procesar.txt
OUTPUT=products.txt

true > $OUTPUT
touch $CAT_PROC $CAT_XPROC $PRD_XPROC $OUTPUT

function existe_generico() {
  grep -c "$1" "$2"
}
function existe_cat_proc() {
  existe_generico "$1" "$CAT_PROC"
}
function existe_cat_xproc() {
  existe_generico "$1" "$CAT_XPROC"
}
function existe_prd_xproc() {
  existe_generico "$1" "$PRD_XPROC"
}
function agrega_cat_nueva() {
  if [[ $(existe_cat_proc "$1") -eq 0 && $(existe_cat_xproc "$1") -eq 0 ]] ; then
    echo "$1" >> "$CAT_XPROC"
  fi
}
function agrega_prd_nuevo() {
  if [ "$(existe_prd_proc "$1")" -eq 0 ] ; then
    echo "$1" >> "$PRD_XPROC"
  fi
}
function procesa_f_envio() {
  F="$(echo "$1" | cut -d ' ' -f 1)"
  A="$(echo "$1" | cut -d ' ' -f 2)"
  IFS=',' read -r -a arrA <<< "$A"
  if [ "$F" == "f_envio" ] ; then
    URL="/tienda/categoriaproducto.asp?idcat=${arrA[0]}&p_categoria=producto&p_indice=${arrA[1]}&p_subindice=${arrA[2]}&todo=1"
    agrega_cat_nueva "$URL"
  elif [ "$F" == "f_envio_categoria_producto" ] ; then
    URL="/tienda/categoriaproducto.asp?idcat=${arrA[1]}&p_categoria=categoriaproductoproducto&p_indice=${arrA[0]}&todo=1"
    agrega_cat_nueva "$URL"
  elif [ "$F" == "f_envio_categoria" ] ; then
    URL="/tienda/categoria.asp?idcat=${arrA[0]}&p_categoria=categoria&p_indice=${arrA[1]}&p_subindice=${arrA[2]}&todo=1"
    agrega_cat_nueva "$URL"
  elif [ "$F" == "f_envio_categoria_especial" ] ; then
    URL="/tienda/categoria.asp?idcat=${arrA[1]}&p_categoria=categoriaespecial&p_indice=${arrA[0]}&todo=1"
    agrega_cat_nueva "$URL"
  fi
}

echo "/tienda/home.asp" > "$CAT_XPROC"

while [ "$(wc -l < "$CAT_XPROC")" -gt 0 ]
do
  NEWCAT="$(head -1 "$CAT_XPROC" )"
  sed -i "" '1d' "$CAT_XPROC"
  curl -s -o temp.html "https://www.travelclub.cl$NEWCAT"
  grep f_envio temp.html | sed -e 's#^.*f_envio#f_envio#g' -e 's#^\([^"]*\)".*$#\1#' -e "s/'//g" | sort -u | grep -E "[0-9]" | tr "()" "  " > lista_f_envio.txt
  while read -r linea
  do
    procesa_f_envio "$linea"
  done < lista_f_envio.txt

  grep -E "producto.asp.*idpro" temp.html | sed -e 's#^.*producto.asp.idpro#/tienda/producto.asp?idpro#' -e 's#".*$##' -e 's#&amp;#\&#' > lista_prod.txt
  sed -i "" "s/';//" lista_prod.txt
  while read -r prod
  do
    agrega_prd_nuevo "$prod"
  done < lista_prod.txt

  echo "$NEWCAT" >> "$CAT_PROC"
done

while read -r urlprd
do
  curl -s -o prd.html "https://www.travelclub.cl$urlprd"
  dos2unix -q prd.html
  NOMBRE="$(grep -A 1 "div class=\"titulo" prd.html | tail -1 | sed -e 's/^[ \t]*//')"
  PRCNORMAL="$(grep -A 5 "Precio-normal" prd.html | tail -1 | sed -e 's/^[ \t]*//')"
  DESCUENTO="$(grep "/Descuento/" prd.html | sed -e 's/^.*_hasta_//' -e 's/.jpg.*$//')"
  AGOTADO="$(grep -c "agotado.jpg" prd.html)"
  if [ "$AGOTADO" -eq 0 ] ; then
    echo "$NOMBRE;$PRCNORMAL;$DESCUENTO" | grep -E -v "^;;$" >> $OUTPUT
  fi
done < "$PRD_XPROC"