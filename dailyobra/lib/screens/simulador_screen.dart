import 'package:flutter/material.dart';
import 'package:dailyobra_comum/dailyobra_comum.dart';

import 'obra_form_screen.dart';
import 'obra_screen.dart';

/// Orçamento rápido sem cadastrar a obra. [podeSalvar] = false quando aberto da tela de login.
class SimuladorScreen extends StatefulWidget {
  const SimuladorScreen({super.key, this.podeSalvar = true});
  final bool podeSalvar;

  @override
  State<SimuladorScreen> createState() => _SimuladorScreenState();
}

class _SimuladorScreenState extends State<SimuladorScreen> {
  ParametrosObra _p = const ParametrosObra(area: '150', padrao: Padrao.medio);

  Future<void> _salvarComoObra() async {
    final id = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => ObraFormScreen(parametrosIniciais: _p)),
    );
    if (id != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ObraScreen(id: id)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final calculo = Calculo.de(_p);
    final r = calculo.resultado;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Simulador de orçamento'),
        actions: [
          if (widget.podeSalvar)
            TextButton(
              onPressed: r == null ? null : _salvarComoObra,
              child: const Text('Salvar como obra'),
            ),
        ],
      ),
      body: Column(
        children: [
          // O resultado fica abaixo do formulário: o total acompanha a rolagem no topo
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: Espaco.s4,
              vertical: Espaco.s3,
            ),
            decoration: BoxDecoration(
              color: context.cores.superficie,
              border: Border(bottom: BorderSide(color: context.cores.borda)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Total estimado',
                    style: t.labelLarge?.copyWith(
                      color: context.cores.textoSuave,
                    ),
                  ),
                ),
                Text(
                  r == null ? '—' : brl.format(r.total),
                  style: t.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: numerosTabulares,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                Espaco.s4,
                Espaco.s4,
                Espaco.s4,
                Espaco.s10,
              ),
              children: [
                Text(
                  'Construção nova residencial, pela tabela de custos da planilha Orçamento de Obra 09.2025.',
                  style: t.bodyMedium?.copyWith(
                    color: context.cores.textoSuave,
                  ),
                ),
                const SizedBox(height: Espaco.s4),
                Painel(
                  titulo: 'Parâmetros',
                  child: Padding(
                    padding: const EdgeInsets.all(Espaco.s4),
                    child: ParametrosForm(
                      inicial: _p,
                      onChanged: (p) => setState(() => _p = p),
                    ),
                  ),
                ),
                const SizedBox(height: Espaco.s4),
                if (r == null)
                  Aviso(calculo.erro!, tom: TomSelo.aviso)
                else ...[
                  Painel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(Espaco.s4),
                          child: BlocoTotal(r: r),
                        ),
                        const Divider(),
                        PainelComposicao(r: r),
                        const NotaEstimativa(),
                      ],
                    ),
                  ),
                  const SizedBox(height: Espaco.s4),
                  ListaEtapas(r: r),
                  const SizedBox(height: Espaco.s4),
                  ListaMateriais(m: listarMateriais(_p.paraEntrada())),
                  if (!widget.podeSalvar) ...[
                    const SizedBox(height: Espaco.s5),
                    Text(
                      'Para salvar a obra e acompanhar o andamento, entre na sua conta.',
                      style: t.bodyMedium?.copyWith(
                        color: context.cores.textoSuave,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
