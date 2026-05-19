resource "aws_secretsmanager_secret" "openai" {
  name        = "petclinic/${var.environment}/openai-api-key"
  description = "OpenAI API key for ${var.project}-${var.environment} genai-service"
  tags        = var.tags
}

resource "aws_secretsmanager_secret_version" "openai" {
  secret_id     = aws_secretsmanager_secret.openai.id
  secret_string = var.openai_api_key
}
