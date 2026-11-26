# Dominio de acceso — pendiente

Al pulsar **Continuar con Google** en el iPhone, iOS muestra un aviso del sistema:

> cofradeo quiere usar `dcsxgppprfedrsrtbatx.supabase.co` para iniciar sesión

El texto lo escribe iOS (`ASWebAuthenticationSession`). No se puede cambiar desde la app. El correo y la contraseña, y **Continuar con Apple**, no lo muestran. Apple entra con la hoja nativa y `signInWithIdToken`.

Quedó en pausa el 26 de noviembre de 2026: el dominio personalizado de Supabase es de pago.

## Qué hay hecho

En Arsys, zona DNS de `circulocofrade.es` (**Entradas DNS**):

| Campo | Valor |
|-------|--------|
| Entrada DNS | `auth.circulocofrade.es` |
| Tipo | CNAME |
| Valor | `dcsxgppprfedrsrtbatx.supabase.co` |

Arsys rechaza el nombre corto `auth`. Hay que escribir el nombre completo. El registro puede quedarse: no cambia la app hasta que Supabase active el dominio.

## Por qué está parado

Para que el aviso diga `auth.circulocofrade.es` hace falta el complemento **Custom domain** de Supabase:

- Plan **Pro** (desde unos 25 €/mes).
- Complemento **Custom domain** (unos 10 €/mes por dominio y proyecto).

El CNAME solo no basta. Supabase tiene que aceptar el dominio y emitir el certificado.

## Si se retoma el dominio de pago

1. Supabase → **Project Settings** → **Add-ons** → activar **Custom domain**.
2. **Project Settings** → **General** → **Custom domains** → `auth.circulocofrade.es` (sin `https://`).
3. Supabase devuelve un TXT (`_acme-challenge.auth.circulocofrade.es` o el nombre que indique). Crearlo en Arsys → **Entradas DNS**, con el nombre completo, y verificar. El certificado puede tardar hasta media hora.
4. Google Cloud → cliente OAuth **Web** → añadir  
   `https://auth.circulocofrade.es/auth/v1/callback`  
   junto a la URL actual `https://dcsxgppprfedrsrtbatx.supabase.co/auth/v1/callback`.
5. Cambiar `SUPABASE_URL` de la app a `https://auth.circulocofrade.es` y publicar un build nuevo de TestFlight. Hasta entonces el iPhone sigue abriendo `supabase.co`.

La URL `dcsxgppprfedrsrtbatx.supabase.co` sigue funcionando después de activar el dominio.

## Alternativa sin pagar

Hacer **Continuar con Google** como Apple: hoja nativa de cuentas de Google y `signInWithIdToken`. El aviso de iOS no sale y nadie ve `supabase.co`. El código actual está en `lib/features/auth/data/auth_repository.dart` (`signInWithGoogle`, `FlutterWebAuth2`).
