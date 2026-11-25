
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function response(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return response({ error: "Método não permitido." }, 405);
  }

  try {
    const authorization = req.headers.get("Authorization");
    if (!authorization) {
      return response({ error: "Usuário não autenticado." }, 401);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const resendApiKey = Deno.env.get("RESEND_API_KEY");
    const sender = Deno.env.get("RESEND_FROM_EMAIL");

    if (!supabaseUrl || !supabaseAnonKey || !resendApiKey || !sender) {
      console.error("Configuração ausente nas variáveis de ambiente.");
      return response({ error: "Configuração do servidor incompleta." }, 500);
    }

    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const {
      data: { user },
      error: userError,
    } = await supabase.auth.getUser();

    if (userError || !user) {
      return response({ error: "Sessão inválida." }, 401);
    }

    const { data: company, error: companyError } = await supabase
      .from("companies")
      .select("id, name, description, phone, address, active")
      .eq("owner_id", user.id)
      .maybeSingle();

    if (companyError) {
      console.error("Erro ao consultar empresa:", companyError.message);
      return response({ error: "Não foi possível consultar a empresa." }, 500);
    }

    if (!company) {
      return response({ error: "Empresa não encontrada." }, 404);
    }

    if (company.active === true) {
      return response(
        { error: "Esta empresa já está aprovada." },
        409,
      );
    }

    const emailText = [
      "Nova solicitação de cadastro no Vanty",
      "",
      `Nome da empresa: ${company.name}`,
      `Descrição: ${company.description || "Não informada"}`,
      `WhatsApp: ${company.phone || "Não informado"}`,
      `Endereço: ${company.address || "Não informado"}`,
      `ID da empresa: ${company.id}`,
      `ID do proprietário: ${user.id}`,
      `E-mail da conta: ${user.email || "Não informado"}`,
      "",
      "A empresa está pendente de aprovação manual.",
    ].join("\n");

    const emailResponse = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${resendApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: "onboarding@resend.dev",
        to: ["roquejr.anjos15@gmail.com"],
        subject: `Vanty — novo cadastro: ${company.name}`,
        text: emailText,
      }),
    });

    const responseText = await emailResponse.text();

    if (!emailResponse.ok) {
      console.error("Falha no envio pelo Resend:", {
        status: emailResponse.status,
        details: responseText,
      });

      return response(
        {
          error: "Não foi possível enviar o e-mail.",
          providerStatus: emailResponse.status,
        },
        502,
      );
    }

    console.log("E-mail aceito pelo Resend:", responseText);

    return response({ success: true });
  } catch (error) {
    console.error("Erro inesperado:", error);
    return response({ error: "Erro interno ao processar a solicitação." }, 500);
  }
});
