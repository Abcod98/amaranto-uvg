# Infraestructura — amaranto-uvg

Sitio estático servido desde **S3 + CloudFront**. Sin servidores, sin
clústers (EC2/ECS/EKS). Solo se crean 2 recursos en tu cuenta AWS: un bucket
S3 privado y una distribución CloudFront que lo sirve por HTTPS.

## Requisitos
- `terraform` (ya instalado)
- `aws` CLI configurado (`aws sts get-caller-identity` debe responder)

## Credenciales para Terraform
Esta cuenta usa `aws login` (sesión de navegador), que Terraform no lee
directamente. Antes de correr cualquier comando de Terraform, exporta la
sesión activa como variables de entorno en tu terminal:
```bash
eval "$(aws configure export-credentials --format env)"
```
Repite esto cada vez que la sesión expire (verás el error "No valid
credential sources found" si ya expiró).

## Primer despliegue
```bash
eval "$(aws configure export-credentials --format env)"
cd infra
terraform init
terraform plan     # revisa qué se va a crear
terraform apply    # crea el bucket S3 + la distribución CloudFront
cd ..
./infra/deploy.sh  # build de Astro + sube dist/ a S3 + invalida caché de CloudFront
```

Al terminar, `terraform -chdir=infra output cloudfront_domain_name` te da la
URL pública (`https://xxxx.cloudfront.net`). CloudFront tarda unos minutos
en propagar la distribución la primera vez.

## Actualizar el sitio
Cada vez que cambies el código, corre de nuevo:
```bash
./infra/deploy.sh
```

## Borrar todo (reversible)
```bash
eval "$(aws configure export-credentials --format env)"
aws s3 rm "s3://$(terraform -chdir=infra output -raw s3_bucket_name)" --recursive
terraform -chdir=infra destroy
```
Terraform no borra un bucket S3 con archivos dentro, por eso hay que
vaciarlo primero. `destroy` elimina exactamente los 2 recursos creados —
nada más en la cuenta se ve afectado.

## Costos
- **Capa gratuita de AWS (12 meses desde la creación de la cuenta):** hasta
  1 TB de salida de datos y 10M requests/mes en CloudFront, y 5 GB de
  almacenamiento en S3. Para este sitio (unos pocos MB) sobra por mucho.
- **Después de los 12 meses:** el costo real es de centavos a un par de
  dólares al mes para un sitio de bajo tráfico (S3 cobra por GB almacenado,
  CloudFront por GB servido). No es "gratis para siempre", pero sigue siendo
  muy barato comparado con mantener un servidor o clúster corriendo 24/7.

## Fuera de alcance (agregar solo si se necesita)
- Dominio propio + certificado ACM + Route53 (cuando se compre el dominio).
- Backend remoto de Terraform state (S3+DynamoDB) — solo hace falta si más
  de una persona corre `terraform apply`.
- CI/CD automático (GitHub Actions) — por ahora `deploy.sh` es manual y
  suficiente.
