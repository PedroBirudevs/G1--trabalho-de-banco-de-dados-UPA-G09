-- =====================================================================
-- QUESTÃO 2 - Consultas estatísticas do UPA Monitor de Porto Velho
-- Aluno: Pedro Henrique Silva - RA 2707527
-- SGBD: PostgreSQL (pgAdmin)
--
-- As tabelas são as MESMAS do DER da Questão 1 (upa, setor,
-- classificacao_risco, coleta, contagem_setor, contagem_risco).
--
-- Interpretação dos nomes:
--   sp_quadro_de_filas -> "QUADRO DE FILAS": quantos pacientes estão
--                         aguardando em cada UPA, por cor de risco
--   sp_atlas_e_cubos   -> "ATLAS" (mapa de todas as UPAs e setores)
--                         + "CUBOS" (operador GROUP BY CUBE, que gera
--                         os subtotais)
--
-- No PostgreSQL uma PROCEDURE não devolve linhas para um SELECT;
-- por isso as duas "sp_" são FUNCTION ... RETURNS TABLE.
-- Uso: SELECT * FROM sp_quadro_de_filas();
--
-- DADOS: todos OFICIAIS, copiados da tela pública do UPA Monitor em
-- 28/10/2026 às 19:25 (uma única leitura). Nenhum dado fictício.
-- Não há acesso ao banco nem ao histórico do sistema.
-- =====================================================================

DROP SCHEMA IF EXISTS upa_monitor CASCADE;
CREATE SCHEMA upa_monitor;
SET search_path TO upa_monitor;

-- ---------------------------------------------------------------------
-- 1) TABELAS (iguais ao script da Questão 1)
-- ---------------------------------------------------------------------
CREATE TABLE upa (
    id_upa            SERIAL PRIMARY KEY,
    nome              VARCHAR(100) NOT NULL,
    tipo              VARCHAR(20)  NOT NULL DEFAULT 'PRINCIPAL',
    id_upa_principal  INT NULL,
    ativa             BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_upa_nome UNIQUE (nome),
    CONSTRAINT ck_upa_tipo CHECK (tipo IN ('PRINCIPAL', 'EXTENSAO')),
    CONSTRAINT fk_upa_principal FOREIGN KEY (id_upa_principal) REFERENCES upa (id_upa)
);

CREATE TABLE setor (
    id_setor  SERIAL PRIMARY KEY,
    nome      VARCHAR(80) NOT NULL,
    icone     VARCHAR(50),
    cor       VARCHAR(20),
    CONSTRAINT uq_setor_nome UNIQUE (nome)
);

CREATE TABLE classificacao_risco (
    id_classificacao  SERIAL PRIMARY KEY,
    nome              VARCHAR(30) NOT NULL,
    cor               VARCHAR(20),
    ordem_prioridade  INT NOT NULL,
    CONSTRAINT uq_classificacao_nome  UNIQUE (nome),
    CONSTRAINT uq_classificacao_ordem UNIQUE (ordem_prioridade)
);

CREATE TABLE coleta (
    id_coleta                      SERIAL PRIMARY KEY,
    id_upa                         INT NOT NULL,
    data_hora                      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    total_aguardando               INT NOT NULL DEFAULT 0,
    tempo_medio_classificacao_seg  INT,
    tempo_medio_consultorio_seg    INT,
    online                         BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT fk_coleta_upa FOREIGN KEY (id_upa) REFERENCES upa (id_upa),
    CONSTRAINT ck_coleta_total CHECK (total_aguardando >= 0),
    CONSTRAINT uq_coleta_upa_data UNIQUE (id_upa, data_hora)
);

CREATE TABLE contagem_setor (
    id_coleta        INT NOT NULL,
    id_setor         INT NOT NULL,
    total_pacientes  INT NOT NULL DEFAULT 0,
    PRIMARY KEY (id_coleta, id_setor),
    CONSTRAINT fk_cs_coleta FOREIGN KEY (id_coleta) REFERENCES coleta (id_coleta) ON DELETE CASCADE,
    CONSTRAINT fk_cs_setor  FOREIGN KEY (id_setor)  REFERENCES setor (id_setor),
    CONSTRAINT ck_cs_total CHECK (total_pacientes >= 0)
);

CREATE TABLE contagem_risco (
    id_coleta         INT NOT NULL,
    id_classificacao  INT NOT NULL,
    total_aguardando  INT NOT NULL DEFAULT 0,
    PRIMARY KEY (id_coleta, id_classificacao),
    CONSTRAINT fk_cr_coleta FOREIGN KEY (id_coleta) REFERENCES coleta (id_coleta) ON DELETE CASCADE,
    CONSTRAINT fk_cr_classificacao FOREIGN KEY (id_classificacao) REFERENCES classificacao_risco (id_classificacao),
    CONSTRAINT ck_cr_total CHECK (total_aguardando >= 0)
);

-- ---------------------------------------------------------------------
-- 2) CADASTROS (vistos no painel)
-- ---------------------------------------------------------------------
INSERT INTO classificacao_risco (nome, cor, ordem_prioridade) VALUES
    ('Emergência',    'vermelho', 1),
    ('Muito urgente', 'laranja',  2),
    ('Urgente',       'amarelo',  3),
    ('Pouco urgente', 'verde',    4),
    ('Não urgente',   'azul',     5);

-- 15 setores do painel (o script da Q1 tinha 14: faltava "Transferências").
INSERT INTO setor (nome) VALUES
    ('Aguardando triagem'), ('Pacientes triados'), ('Atendidos consultório'),
    ('Sutura'), ('Sala vermelha'), ('Observação masculina'),
    ('Observação feminina'), ('Observação infantil'), ('Medicação administrada'),
    ('Exames laboratório'), ('Exames radiologia'), ('Atendimento pediátrico'),
    ('Odontologia'), ('Assistência social'), ('Transferências');

INSERT INTO upa (nome, tipo, id_upa_principal) VALUES ('UPA Leste', 'PRINCIPAL', NULL);
INSERT INTO upa (nome, tipo, id_upa_principal) VALUES
    ('UPA Leste Extensão - Odontologia', 'EXTENSAO', (SELECT id_upa FROM upa WHERE nome = 'UPA Leste'));
INSERT INTO upa (nome) VALUES
    ('UPA Sul'), ('Ana Adelaide'), ('UPA José Adelino da Silva'), ('Jaci Paraná');

-- ---------------------------------------------------------------------
-- 3) COLETA OFICIAL - painel em 28/10/2026 às 19:25
--    Os tempos médios ficam NULL: o painel não mostrava esses tempos
--    nessa leitura (não inventamos valor).
-- ---------------------------------------------------------------------
INSERT INTO coleta (id_upa, data_hora, total_aguardando, online)
SELECT u.id_upa, TIMESTAMP '2026-10-28 19:25', v.total, TRUE
  FROM (VALUES
    ('UPA Leste', 6),
    ('UPA Leste Extensão - Odontologia', 0),
    ('UPA Sul', 26),
    ('Ana Adelaide', 12),
    ('UPA José Adelino da Silva', 4),
    ('Jaci Paraná', 0)
       ) AS v(upa, total)
  JOIN upa u ON u.nome = v.upa;

-- Classificação de risco (aguardando)
INSERT INTO contagem_risco (id_coleta, id_classificacao, total_aguardando)
SELECT c.id_coleta, k.id_classificacao, v.qtd
  FROM (VALUES
    ('UPA Leste', 'Emergência', 0),
    ('UPA Leste', 'Muito urgente', 0),
    ('UPA Leste', 'Urgente', 1),
    ('UPA Leste', 'Pouco urgente', 5),
    ('UPA Leste', 'Não urgente', 0),
    ('UPA Leste Extensão - Odontologia', 'Emergência', 0),
    ('UPA Leste Extensão - Odontologia', 'Muito urgente', 0),
    ('UPA Leste Extensão - Odontologia', 'Urgente', 0),
    ('UPA Leste Extensão - Odontologia', 'Pouco urgente', 0),
    ('UPA Leste Extensão - Odontologia', 'Não urgente', 0),
    ('UPA Sul', 'Emergência', 0),
    ('UPA Sul', 'Muito urgente', 0),
    ('UPA Sul', 'Urgente', 3),
    ('UPA Sul', 'Pouco urgente', 23),
    ('UPA Sul', 'Não urgente', 0),
    ('Ana Adelaide', 'Emergência', 0),
    ('Ana Adelaide', 'Muito urgente', 0),
    ('Ana Adelaide', 'Urgente', 2),
    ('Ana Adelaide', 'Pouco urgente', 8),
    ('Ana Adelaide', 'Não urgente', 2),
    ('UPA José Adelino da Silva', 'Emergência', 0),
    ('UPA José Adelino da Silva', 'Muito urgente', 0),
    ('UPA José Adelino da Silva', 'Urgente', 0),
    ('UPA José Adelino da Silva', 'Pouco urgente', 4),
    ('UPA José Adelino da Silva', 'Não urgente', 0),
    ('Jaci Paraná', 'Emergência', 0),
    ('Jaci Paraná', 'Muito urgente', 0),
    ('Jaci Paraná', 'Urgente', 0),
    ('Jaci Paraná', 'Pouco urgente', 0),
    ('Jaci Paraná', 'Não urgente', 0)
       ) AS v(upa, classificacao, qtd)
  JOIN upa u                 ON u.nome = v.upa
  JOIN coleta c              ON c.id_upa = u.id_upa AND c.data_hora = TIMESTAMP '2026-10-28 19:25'
  JOIN classificacao_risco k ON k.nome = v.classificacao;

-- Pacientes por setor
INSERT INTO contagem_setor (id_coleta, id_setor, total_pacientes)
SELECT c.id_coleta, s.id_setor, v.qtd
  FROM (VALUES
    ('UPA Leste', 'Aguardando triagem', 1),
    ('UPA Leste', 'Pacientes triados', 265),
    ('UPA Leste', 'Atendidos consultório', 224),
    ('UPA Leste', 'Sutura', 32),
    ('UPA Leste', 'Sala vermelha', 4),
    ('UPA Leste', 'Observação masculina', 8),
    ('UPA Leste', 'Observação feminina', 2),
    ('UPA Leste', 'Observação infantil', 0),
    ('UPA Leste', 'Medicação administrada', 403),
    ('UPA Leste', 'Exames laboratório', 137),
    ('UPA Leste', 'Exames radiologia', 76),
    ('UPA Leste', 'Odontologia', 1),
    ('UPA Leste', 'Atendimento pediátrico', 49),
    ('UPA Leste', 'Assistência social', 5),
    ('UPA Leste', 'Transferências', 17),
    ('UPA Leste Extensão - Odontologia', 'Aguardando triagem', 0),
    ('UPA Leste Extensão - Odontologia', 'Pacientes triados', 0),
    ('UPA Leste Extensão - Odontologia', 'Atendidos consultório', 0),
    ('UPA Leste Extensão - Odontologia', 'Sutura', 0),
    ('UPA Leste Extensão - Odontologia', 'Sala vermelha', 0),
    ('UPA Leste Extensão - Odontologia', 'Observação masculina', 0),
    ('UPA Leste Extensão - Odontologia', 'Observação feminina', 0),
    ('UPA Leste Extensão - Odontologia', 'Observação infantil', 0),
    ('UPA Leste Extensão - Odontologia', 'Medicação administrada', 0),
    ('UPA Leste Extensão - Odontologia', 'Exames laboratório', 0),
    ('UPA Leste Extensão - Odontologia', 'Exames radiologia', 0),
    ('UPA Leste Extensão - Odontologia', 'Odontologia', 8),
    ('UPA Leste Extensão - Odontologia', 'Atendimento pediátrico', 0),
    ('UPA Leste Extensão - Odontologia', 'Assistência social', 0),
    ('UPA Leste Extensão - Odontologia', 'Transferências', 0),
    ('UPA Sul', 'Aguardando triagem', 1),
    ('UPA Sul', 'Pacientes triados', 285),
    ('UPA Sul', 'Atendidos consultório', 212),
    ('UPA Sul', 'Sutura', 38),
    ('UPA Sul', 'Sala vermelha', 4),
    ('UPA Sul', 'Observação masculina', 14),
    ('UPA Sul', 'Observação feminina', 17),
    ('UPA Sul', 'Observação infantil', 5),
    ('UPA Sul', 'Medicação administrada', 332),
    ('UPA Sul', 'Exames laboratório', 303),
    ('UPA Sul', 'Exames radiologia', 98),
    ('UPA Sul', 'Odontologia', 15),
    ('UPA Sul', 'Atendimento pediátrico', 43),
    ('UPA Sul', 'Assistência social', 0),
    ('UPA Sul', 'Transferências', 20),
    ('Ana Adelaide', 'Aguardando triagem', 6),
    ('Ana Adelaide', 'Pacientes triados', 221),
    ('Ana Adelaide', 'Atendidos consultório', 196),
    ('Ana Adelaide', 'Sutura', 15),
    ('Ana Adelaide', 'Sala vermelha', 2),
    ('Ana Adelaide', 'Observação masculina', 34),
    ('Ana Adelaide', 'Observação feminina', 31),
    ('Ana Adelaide', 'Observação infantil', 5),
    ('Ana Adelaide', 'Medicação administrada', 371),
    ('Ana Adelaide', 'Exames laboratório', 209),
    ('Ana Adelaide', 'Exames radiologia', 66),
    ('Ana Adelaide', 'Odontologia', 0),
    ('Ana Adelaide', 'Atendimento pediátrico', 50),
    ('Ana Adelaide', 'Assistência social', 0),
    ('Ana Adelaide', 'Transferências', 1),
    ('UPA José Adelino da Silva', 'Aguardando triagem', 0),
    ('UPA José Adelino da Silva', 'Pacientes triados', 195),
    ('UPA José Adelino da Silva', 'Atendidos consultório', 180),
    ('UPA José Adelino da Silva', 'Sutura', 1),
    ('UPA José Adelino da Silva', 'Sala vermelha', 7),
    ('UPA José Adelino da Silva', 'Observação masculina', 0),
    ('UPA José Adelino da Silva', 'Observação feminina', 0),
    ('UPA José Adelino da Silva', 'Observação infantil', 0),
    ('UPA José Adelino da Silva', 'Medicação administrada', 313),
    ('UPA José Adelino da Silva', 'Exames laboratório', 92),
    ('UPA José Adelino da Silva', 'Exames radiologia', 44),
    ('UPA José Adelino da Silva', 'Odontologia', 0),
    ('UPA José Adelino da Silva', 'Atendimento pediátrico', 40),
    ('UPA José Adelino da Silva', 'Assistência social', 0),
    ('UPA José Adelino da Silva', 'Transferências', 1),
    ('Jaci Paraná', 'Aguardando triagem', 0),
    ('Jaci Paraná', 'Pacientes triados', 47),
    ('Jaci Paraná', 'Atendidos consultório', 41),
    ('Jaci Paraná', 'Sutura', 1),
    ('Jaci Paraná', 'Sala vermelha', 0),
    ('Jaci Paraná', 'Observação masculina', 4),
    ('Jaci Paraná', 'Observação feminina', 7),
    ('Jaci Paraná', 'Observação infantil', 1),
    ('Jaci Paraná', 'Medicação administrada', 65),
    ('Jaci Paraná', 'Exames laboratório', 21),
    ('Jaci Paraná', 'Exames radiologia', 11),
    ('Jaci Paraná', 'Odontologia', 0),
    ('Jaci Paraná', 'Atendimento pediátrico', 11),
    ('Jaci Paraná', 'Assistência social', 0),
    ('Jaci Paraná', 'Transferências', 1)
       ) AS v(upa, setor, qtd)
  JOIN upa u    ON u.nome = v.upa
  JOIN coleta c ON c.id_upa = u.id_upa AND c.data_hora = TIMESTAMP '2026-10-28 19:25'
  JOIN setor s  ON s.nome = v.setor;

-- ---------------------------------------------------------------------
-- 4) sp_quadro_de_filas
--    Fila de cada UPA na coleta mais recente (até a data informada).
--    Regras (correções feitas na saída da IA):
--      * fila = soma das 5 cores de risco ("Total" do card da UPA)
--      * "Aguardando triagem" vem em coluna separada: o painel NÃO soma
--        esse número ao total (Ana Adelaide: total 12 com 6 aguardando triagem)
--      * casos_criticos = Emergência + Muito urgente aguardando
--        (o painel mostrava 0 com 17 pacientes nas Salas Vermelhas,
--        então a Sala Vermelha não entra nessa conta)
--      * confere_total: compara a soma das cores com o total_aguardando
--        gravado na coleta (o total é guardado, então pode divergir)
--      * tempos em minutos; NULL quando o painel não publicou
--      * ROW_NUMBER escolhe a última coleta de cada UPA
--      * ROLLUP gera a linha TOTAL GERAL (= "Resumo geral" do painel)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_quadro_de_filas(
    p_data DATE DEFAULT NULL           -- NULL = coleta mais recente
)
RETURNS TABLE (
    upa VARCHAR, data_hora TIMESTAMP,
    emergencia BIGINT, muito_urgente BIGINT, urgente BIGINT,
    pouco_urgente BIGINT, nao_urgente BIGINT,
    total_aguardando BIGINT, casos_criticos BIGINT, aguardando_triagem BIGINT,
    pct_baixa_gravidade NUMERIC,
    tempo_classificacao_min NUMERIC, tempo_consultorio_min NUMERIC,
    confere_total TEXT
)
LANGUAGE sql STABLE AS $$
    WITH ultima AS (
        SELECT c.*,
               ROW_NUMBER() OVER (PARTITION BY c.id_upa ORDER BY c.data_hora DESC) AS rn
          FROM coleta c
         WHERE p_data IS NULL OR c.data_hora < p_data + 1
    ),
    fila AS (
        SELECT u.nome AS upa, ul.data_hora,
               SUM(CASE WHEN k.ordem_prioridade = 1 THEN cr.total_aguardando ELSE 0 END) AS emergencia,
               SUM(CASE WHEN k.ordem_prioridade = 2 THEN cr.total_aguardando ELSE 0 END) AS muito_urgente,
               SUM(CASE WHEN k.ordem_prioridade = 3 THEN cr.total_aguardando ELSE 0 END) AS urgente,
               SUM(CASE WHEN k.ordem_prioridade = 4 THEN cr.total_aguardando ELSE 0 END) AS pouco_urgente,
               SUM(CASE WHEN k.ordem_prioridade = 5 THEN cr.total_aguardando ELSE 0 END) AS nao_urgente,
               MAX(ul.total_aguardando) AS total_gravado,
               (SELECT cs.total_pacientes
                  FROM contagem_setor cs JOIN setor s ON s.id_setor = cs.id_setor
                 WHERE cs.id_coleta = ul.id_coleta AND s.nome = 'Aguardando triagem') AS aguardando_triagem,
               MAX(ul.tempo_medio_classificacao_seg) AS t_class,
               MAX(ul.tempo_medio_consultorio_seg)   AS t_cons
          FROM ultima ul
          JOIN upa u                 ON u.id_upa = ul.id_upa
          JOIN contagem_risco cr     ON cr.id_coleta = ul.id_coleta
          JOIN classificacao_risco k ON k.id_classificacao = cr.id_classificacao
         WHERE ul.rn = 1
         GROUP BY u.nome, ul.id_coleta, ul.data_hora
    )
    SELECT (CASE WHEN GROUPING(upa) = 1 THEN 'TOTAL GERAL' ELSE upa END)::VARCHAR,
           MAX(data_hora),
           SUM(emergencia), SUM(muito_urgente), SUM(urgente),
           SUM(pouco_urgente), SUM(nao_urgente),
           SUM(emergencia + muito_urgente + urgente + pouco_urgente + nao_urgente),
           SUM(emergencia + muito_urgente),
           SUM(aguardando_triagem),
           ROUND(100.0 * SUM(pouco_urgente + nao_urgente)
                 / NULLIF(SUM(emergencia + muito_urgente + urgente + pouco_urgente + nao_urgente), 0), 1),
           ROUND(AVG(t_class) / 60.0, 1),
           ROUND(AVG(t_cons)  / 60.0, 1),
           CASE WHEN SUM(emergencia + muito_urgente + urgente + pouco_urgente + nao_urgente)
                     = SUM(total_gravado) THEN 'OK' ELSE 'DIVERGE' END
      FROM fila
     GROUP BY ROLLUP (upa)
     ORDER BY GROUPING(upa), 8 DESC, 1;
$$;

-- ---------------------------------------------------------------------
-- 5) sp_atlas_e_cubos
--    Desempenho por UPA e por SETOR com GROUP BY CUBE (upa, setor):
--      linha UPA + setor   -> valor do setor naquela UPA
--      linha TODAS + setor -> total do setor na rede
--    + % de participação da UPA no setor e posição (ROW_NUMBER).
--    "Aguardando triagem" fica de fora (é fila, está no quadro de filas).
--    O CUBE também gera "UPA x TODOS OS SETORES", que soma coisas
--    diferentes (medicações + exames + triados...). Esse número não
--    significa nada, por isso essas linhas são descartadas.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_atlas_e_cubos(
    p_data  DATE        DEFAULT NULL,
    p_setor VARCHAR(80) DEFAULT NULL    -- filtro opcional por setor
)
RETURNS TABLE (
    upa VARCHAR, setor VARCHAR, quantidade BIGINT,
    pct_no_setor NUMERIC, posicao_no_setor BIGINT
)
LANGUAGE sql STABLE AS $$
    WITH ultima AS (
        SELECT c.*,
               ROW_NUMBER() OVER (PARTITION BY c.id_upa ORDER BY c.data_hora DESC) AS rn
          FROM coleta c
         WHERE p_data IS NULL OR c.data_hora < p_data + 1
    ),
    base AS (
        SELECT u.nome AS upa, s.nome AS setor, cs.total_pacientes AS qtd
          FROM ultima ul
          JOIN upa u             ON u.id_upa = ul.id_upa
          JOIN contagem_setor cs ON cs.id_coleta = ul.id_coleta
          JOIN setor s           ON s.id_setor = cs.id_setor
         WHERE ul.rn = 1
           AND s.nome <> 'Aguardando triagem'
           AND (p_setor IS NULL OR s.nome = p_setor)
    ),
    cubo AS (
        SELECT upa, setor,
               GROUPING(upa)   AS g_upa,
               GROUPING(setor) AS g_setor,
               SUM(qtd)        AS qtd
          FROM base
         GROUP BY CUBE (upa, setor)
    )
    SELECT (CASE WHEN c.g_upa = 1 THEN 'TODAS AS UPAs' ELSE c.upa END)::VARCHAR,
           c.setor::VARCHAR,
           c.qtd,
           CASE WHEN c.g_upa = 0 THEN ROUND(100.0 * c.qtd / NULLIF(t.qtd, 0), 1) END,
           CASE WHEN c.g_upa = 0 THEN
                ROW_NUMBER() OVER (PARTITION BY c.setor, c.g_upa ORDER BY c.qtd DESC, c.upa)
           END
      FROM cubo c
      LEFT JOIN cubo t ON t.setor = c.setor AND t.g_upa = 1 AND t.g_setor = 0
     WHERE c.g_setor = 0
     ORDER BY c.setor, c.g_upa, c.qtd DESC, c.upa;
$$;

-- ---------------------------------------------------------------------
-- 6) TESTES - selecione cada SELECT, aperte F5 e tire o print
-- ---------------------------------------------------------------------
-- 6.1 Quadro de filas (deve bater com o painel: total 48, críticos 0)
SELECT * FROM sp_quadro_de_filas();

-- 6.2 Atlas completo (UPA x setor + total da rede)
SELECT * FROM sp_atlas_e_cubos();

-- 6.3 Atlas de um setor só
SELECT * FROM sp_atlas_e_cubos(p_setor => 'Exames laboratório');

-- 6.4 Prova do erro da IA na view do script da Q1:
--     somar todos os setores NÃO dá o "Total Atendimentos" do painel (1048)
SELECT SUM(total_pacientes) AS soma_de_todos_os_setores
  FROM contagem_setor;
