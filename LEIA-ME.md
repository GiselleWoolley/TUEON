# Diário da Gira · como colocar no ar

São dois arquivos:

- `index.html`: o app completo (login, registro, roda, caderno, diagnóstico e turmas).
- `supabase-schema.sql`: o banco de dados, com as regras de acesso e de convite.

Tempo estimado: 20 a 30 minutos. Tudo nos planos gratuitos.

---

## 1. Criar o banco no Supabase

1. Entre em **supabase.com** e crie uma conta.
2. Clique em **New project**.
   - Nome: `diario-da-gira`
   - Database password: crie uma senha forte e guarde
   - Region: **South America (São Paulo)**
3. Espere o projeto ficar pronto (cerca de 2 minutos).

## 2. Rodar o script do banco

1. No menu lateral, abra **SQL Editor** e clique em **New query**.
2. Abra o arquivo `supabase-schema.sql`, copie tudo e cole no editor.
3. **Na última parte do script**, troque `seu-email@exemplo.com` pelo seu e-mail (em minúsculas) e `Seu nome` pelo seu nome. É isso que faz de você a primeira dirigente.
4. Clique em **Run**. Deve aparecer "Success".

## 3. Ajustar o login

1. Abra **Authentication** → **Sign In / Providers** → **Email**.
2. Desligue **Confirm email** e salve.
   - Por quê: o plano gratuito envia poucos e-mails por hora. Como só e-mails convidados conseguem criar conta, a confirmação não é necessária. O e-mail continua sendo usado para "Esqueci minha senha".

## 4. Copiar as chaves para o app

1. Abra **Project Settings** → **API** (ou **Data API** / **API Keys**).
2. Copie a **Project URL** e a chave **anon public**.
3. Abra o `index.html` num editor de texto (Bloco de Notas serve) e procure estas duas linhas, logo no início do código:

   ```
   const SUPABASE_URL="COLE_AQUI_A_PROJECT_URL";
   const SUPABASE_ANON_KEY="COLE_AQUI_A_ANON_PUBLIC_KEY";
   ```

4. Cole cada valor entre as aspas e salve o arquivo.

A chave "anon public" pode ficar no site: quem protege os dados são as regras do banco. **Nunca** use a chave `service_role` no app.

## 5. Subir o app para o GitHub

1. Entre em **github.com** e crie uma conta, se ainda não tiver.
2. Clique em **New repository**. Nome: `diario-da-gira`. Pode ser público. Crie.
3. Clique em **Add file** → **Upload files**, arraste o `index.html` e clique em **Commit changes**.

## 6. Publicar no Render

1. Entre em **render.com** e crie uma conta (pode entrar com o GitHub).
2. Clique em **New** → **Static Site** e escolha o repositório `diario-da-gira`.
3. Preencha:
   - Build Command: deixe em branco
   - Publish Directory: `.`
4. Clique em **Create Static Site**. Em 1 ou 2 minutos você recebe um endereço como `https://diario-da-gira.onrender.com`.

## 7. Avisar o Supabase sobre o endereço do site

1. No Supabase, abra **Authentication** → **URL Configuration**.
2. Em **Site URL**, cole o endereço do Render.
3. Em **Redirect URLs**, adicione o mesmo endereço terminado em `/**` (ex.: `https://diario-da-gira.onrender.com/**`).
4. Salve. Isso faz o link de "Esqueci minha senha" voltar para o app.

## 8. Primeiro acesso

1. Abra o endereço do Render.
2. Toque em **Primeiro acesso**, use o e-mail que você colocou no script e crie sua senha.
3. Você entra como **Dirigente**. Na aba **Turmas**:
   - crie a turma;
   - em **Convidar alguém**, preencha nome, e-mail, perfil e turma;
   - toque em **Copiar convite** e envie a mensagem pelo WhatsApp.
4. A pessoa abre o link, toca em **Primeiro acesso** e cria a senha com o e-mail convidado.

---

## Como o app protege os dados

- Só cria conta quem tem convite. Outros e-mails são recusados pelo próprio banco.
- O diário de cada pessoa é privado. Nem a dirigente consegue ler.
- A roda e o caderno só aparecem para quem é da turma (e para a dirigente).
- O caderno é sempre anônimo.
- Apagar um registro apaga também a partilha dele na roda e no caderno.

## Bom saber

- **Projeto pausado:** o Supabase gratuito pausa projetos que ficam uma semana sem nenhum acesso. Se o app parar de entrar, abra o painel do Supabase e clique em **Restore project**.
- **Atualizar o app:** troque o `index.html` no GitHub (Add file → Upload files). O Render publica sozinho em seguida. Lembre de manter as duas chaves preenchidas.
- **Mudar alguém de perfil:** na aba Turmas, em "Pessoas com conta", use **Tornar dirigente** ou **Tornar cursista**.
- **Pessoa esqueceu a senha:** ela usa **Esqueci minha senha** na tela de entrada.
