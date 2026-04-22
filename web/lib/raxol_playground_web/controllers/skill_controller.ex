defmodule RaxolPlaygroundWeb.SkillController do
  @moduledoc """
  Serves the Raxol agent onboarding skill file at /skill.md.
  """
  use RaxolPlaygroundWeb, :controller

  @skill_path Path.join(:code.priv_dir(:raxol_playground), "static/skill.md")
  @skill_content (case File.read(@skill_path) do
                    {:ok, content} -> content
                    {:error, _} -> "# Raxol\n\nSkill file not found."
                  end)

  def show(conn, _params) do
    conn
    |> put_resp_content_type("text/markdown")
    |> put_resp_header("cache-control", "public, max-age=3600")
    |> send_resp(200, @skill_content)
  end
end
