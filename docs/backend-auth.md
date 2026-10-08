# ChemVision 账号与管理员后端

账号服务使用 Supabase Auth、Postgres RLS 和 Edge Functions。应用支持邮箱密码注册/登录与 GitHub OAuth；本地访客模式仍可使用。当前 Hive 学习记录保存在设备，不会因登录而上传或跨设备同步。

管理员权限只授予通过 GitHub OAuth 验证、GitHub 用户名为 `panda-lsy` 的 identity。数据库不接受客户端提交的角色字段，管理员用户目录也由 Edge Function 在服务端鉴权后读取。

## 初始化 Supabase

1. 创建 Supabase 项目，并记录 Project URL、Publishable Key。
2. 安装 Supabase CLI 并在仓库根目录执行 `supabase link --project-ref <项目 ID>`。
3. 执行 `supabase db push`，应用 `supabase/migrations/` 中的迁移。
4. 创建 GitHub OAuth App。GitHub OAuth App 的 Authorization callback URL 填 Supabase Dashboard「Authentication → Sign In / Providers → GitHub」显示的 callback URL（格式为 `https://<project-ref>.supabase.co/auth/v1/callback`），然后将 Client ID 与 Client Secret 配置在 Supabase Dashboard 的 GitHub provider 中。Client Secret 不要写入客户端或仓库。
5. 在 Supabase Auth URL Configuration 中，将 Site URL 设为 `https://chemvision.qzz.io/`，并将 `https://chemvision.qzz.io/`、开发地址以及 `com.chemvision.chemvision://auth-callback/` 加入 Redirect URLs。iOS/Android 的自定义 URI scheme 已写入平台配置。
6. 在 Supabase Auth 中将最低密码长度设为 8 位。邮箱确认/密码注册使用 Resend SMTP。在 Authentication → Emails → SMTP Settings 中填写：发件地址（例如 `no-reply@<verified-domain>`）、发件人名称 `ChemVision`、SMTP 主机 `smtp.resend.com`、端口 `465`、用户名 `resend`、密码为 Resend API Key。建议新建仅有 sending access 且限定到已验证域的 API Key；只粘贴到 Supabase SMTP 设置，不要放入 GitHub Actions 或仓库。确认邮件的跳转地址必须在 Redirect URLs 中。
7. 部署管理员函数：

   ```sh
   supabase functions deploy admin-users
   ```

   Edge Function 需要 Supabase 自动提供的 `SUPABASE_URL`、`SUPABASE_ANON_KEY` 和 `SUPABASE_SERVICE_ROLE_KEY`。若当前项目没有注入 `SUPABASE_SERVICE_ROLE_KEY`，仅通过 Supabase secrets 配置该密钥。它绝不能进入 Flutter 编译参数或客户端代码。

## 运行应用

Publishable Key 是面向客户端的公开密钥，可以作为构建参数传入；数据库 RLS 与 Edge Function 鉴权负责保护数据和管理操作。不要传入 `service_role` secret key。

```sh
flutter run \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable-key>
```

发布构建也要提供相同的两个 `--dart-define`。没有配置时应用继续以访客模式运行，账号页会提示缺少配置。

GitHub Actions 构建从仓库 **Settings → Secrets and variables → Actions → Variables** 读取 `SUPABASE_URL` 和 `SUPABASE_PUBLISHABLE_KEY`。配置这两个公开变量后，Android、Windows 和 Web 构建会自动注入它们；不要将 `service_role` key 配置为客户端变量。

## 平台回调

- Web：OAuth 与邮箱确认回到当前站点路径；将正式站点和开发站点加入 Supabase Redirect URLs。
- Android/iOS：回调 URI 为 `com.chemvision.chemvision://auth-callback/`，平台 scheme 已登记。
- Windows：首次使用 OAuth 前，在解压后的发行目录运行 `powershell -ExecutionPolicy Bypass -File .\register_auth_protocol.ps1`。脚本会把该 URL scheme 注册到当前 Windows 用户，使外部浏览器能把回调交还给 ChemVision；卸载时可用 `-Unregister` 移除注册。

## Owner 安全规则

- `public.is_chemvision_owner()` 只查询 Supabase Auth 的 GitHub identity 记录，不依赖可修改的用户 metadata。
- `admin-users` 函数再次验证 Bearer access token，调用 Owner RPC；只有结果为 true 才使用服务端 service-role key 分页读取用户目录。
- 用户列表只返回邮箱、注册/最近登录时间、登录 provider 和 GitHub 用户名；函数不提供封禁、删除或提权操作。
- `profiles` 表启用 RLS，只允许用户读取/更新自己的展示名和头像。角色字段不在客户端表中。
