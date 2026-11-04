import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../marketplace/cep.dart';
import '../marketplace/texto.dart';
import '../obras/obra.dart';
import '../supabase/erros.dart';
import '../tema/cores.dart';
import '../tema/tema.dart';
import 'ui.dart';

/// CEP como 00000-000 enquanto digita (só números, até 8).
class MascaraCep extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue antigo, TextEditingValue novo) {
    final d = novo.text.replaceAll(RegExp(r'\D'), '');
    final numeros = d.length > 8 ? d.substring(0, 8) : d;
    final texto = numeros.length > 5 ? '${numeros.substring(0, 5)}-${numeros.substring(5)}' : numeros;
    return TextEditingValue(text: texto, selection: TextSelection.collapsed(offset: texto.length));
  }
}

/// Cidade e estado sem digitar: pelo CEP ou escolhendo na lista do IBGE. A lista evita erro de grafia, porque as lojas da
/// cidade só aparecem primeiro quando o nome confere. Se o IBGE estiver fora do ar, a lista deixa digitar a cidade.
class CampoRegiao extends StatefulWidget {
  const CampoRegiao({
    super.key,
    required this.cidade,
    required this.uf,
    required this.onEscolher,
    this.rotulo = 'Cidade e estado',
    this.obrigatorio = false,
    this.ajuda,
    this.erro,
    this.onCep,
    this.consultarCep = buscarCep,
    this.consultarCidades = cidadesDoEstado,
  });
  final String cidade;
  final String uf;
  final void Function(String cidade, String uf) onEscolher;
  final String rotulo;
  final bool obrigatorio;
  final String? ajuda;
  final String? erro;

  /// Endereço completo do CEP, para quem também quer a rua e o bairro.
  final ValueChanged<EnderecoCep>? onCep;
  final BuscarCep consultarCep;
  final BuscarCidades consultarCidades;

  @override
  State<CampoRegiao> createState() => _CampoRegiaoState();
}

class _CampoRegiaoState extends State<CampoRegiao> {
  final _cep = TextEditingController();
  bool _trocando = false;
  bool _buscando = false;
  String? _erroCep;
  int _pedido = 0;

  @override
  void dispose() {
    _cep.dispose();
    super.dispose();
  }

  void _aplicar(String cidade, String uf) {
    setState(() {
      _trocando = false;
      _erroCep = null;
      _cep.clear();
    });
    widget.onEscolher(cidade, uf);
  }

  Future<void> _aoDigitarCep(String texto) async {
    final cep = texto.replaceAll(RegExp(r'\D'), '');
    final meu = ++_pedido;
    if (cep.length < 8) {
      if (_erroCep != null || _buscando) {
        setState(() {
          _erroCep = null;
          _buscando = false;
        });
      }
      return;
    }
    setState(() {
      _buscando = true;
      _erroCep = null;
    });
    try {
      final achado = await widget.consultarCep(cep);
      if (!mounted || meu != _pedido) return;
      setState(() {
        _buscando = false;
        if (achado == null) _erroCep = 'CEP não encontrado. Confira os números ou escolha na lista.';
      });
      if (achado != null) {
        _aplicar(achado.cidade, achado.uf);
        widget.onCep?.call(achado);
      }
    } on FalhaComMensagem {
      if (!mounted || meu != _pedido) return;
      setState(() {
        _buscando = false;
        _erroCep = 'Não deu para buscar o CEP agora. Escolha na lista.';
      });
    }
  }

  Future<void> _escolherNaLista() async {
    FocusScope.of(context).unfocus();
    final escolha = await showModalBottomSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ListaDeCidades(buscar: widget.consultarCidades),
    );
    if (escolha != null) _aplicar(escolha.$1, escolha.$2);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = context.cores;
    final preenchida = widget.cidade.isNotEmpty && !_trocando;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Rotulo(widget.rotulo, obrigatorio: widget.obrigatorio),
        if (preenchida)
          Container(
            padding: const EdgeInsets.only(left: Espaco.s3),
            decoration: BoxDecoration(
              color: c.superficieSutil,
              borderRadius: BorderRadius.circular(Raio.md),
              border: Border.all(color: c.borda),
            ),
            child: Row(
              children: [
                Icon(Icons.place_outlined, size: 20, color: c.textoSuave),
                const SizedBox(width: Espaco.s2),
                Expanded(
                  child: Text(
                    widget.uf.isEmpty ? widget.cidade : '${widget.cidade} · ${widget.uf}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyLarge,
                  ),
                ),
                TextButton(onPressed: () => setState(() => _trocando = true), child: const Text('Trocar')),
              ],
            ),
          )
        else ...[
          TextField(
            key: const Key('regiao-cep'),
            controller: _cep,
            keyboardType: TextInputType.number,
            inputFormatters: [MascaraCep()],
            onChanged: _aoDigitarCep,
            decoration: InputDecoration(
              hintText: 'Digite o CEP',
              errorText: _erroCep,
              errorMaxLines: 2,
              suffixIcon: _buscando
                  ? const Padding(
                      padding: EdgeInsets.all(Espaco.s3),
                      child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : null,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: _escolherNaLista, child: const Text('Não sei o CEP')),
          ),
        ],
        if (widget.erro != null) ...[
          const SizedBox(height: Espaco.s1),
          Text(widget.erro!, style: t.bodySmall?.copyWith(color: c.erro)),
        ],
        if (widget.ajuda != null) ...[
          const SizedBox(height: Espaco.s1),
          Text(widget.ajuda!, style: t.bodySmall?.copyWith(color: c.textoSuave)),
        ],
      ],
    );
  }
}

/// Folha de baixo: escolhe o estado e depois a cidade. Devolve (cidade, uf).
class _ListaDeCidades extends StatefulWidget {
  const _ListaDeCidades({required this.buscar});
  final BuscarCidades buscar;

  @override
  State<_ListaDeCidades> createState() => _ListaDeCidadesState();
}

class _ListaDeCidadesState extends State<_ListaDeCidades> {
  final _busca = TextEditingController();
  final _digitada = TextEditingController();
  String? _uf;
  List<String>? _cidades;
  bool _falhou = false;
  int _pedido = 0;

  @override
  void dispose() {
    _busca.dispose();
    _digitada.dispose();
    super.dispose();
  }

  Future<void> _carregar(String uf) async {
    final meu = ++_pedido;
    setState(() {
      _uf = uf;
      _cidades = null;
      _falhou = false;
      _busca.clear();
    });
    try {
      final cidades = await widget.buscar(uf);
      if (mounted && meu == _pedido) setState(() => _cidades = cidades);
    } on FalhaComMensagem {
      if (mounted && meu == _pedido) setState(() => _falhou = true);
    }
  }

  void _voltarAoEstado() {
    _pedido++;
    setState(() {
      _uf = null;
      _cidades = null;
      _falhou = false;
    });
  }

  Widget _estados(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(Espaco.s4),
    child: Wrap(
      spacing: Espaco.s2,
      runSpacing: Espaco.s2,
      children: [for (final u in ufs) ActionChip(label: Text(u), onPressed: () => _carregar(u))],
    ),
  );

  Widget _semLista(BuildContext context, String uf) => ListView(
    padding: const EdgeInsets.all(Espaco.s4),
    children: [
      const Aviso('Não deu para carregar as cidades.'),
      const SizedBox(height: Espaco.s2),
      OutlinedButton(onPressed: () => _carregar(uf), child: const Text('Tentar de novo')),
      const SizedBox(height: Espaco.s4),
      CampoTexto(rotulo: 'Ou digite a cidade', controller: _digitada),
      const SizedBox(height: Espaco.s2),
      FilledButton(
        onPressed: () {
          final cidade = _digitada.text.trim();
          if (cidade.length >= 2) Navigator.pop(context, (cidade, uf));
        },
        child: const Text('Usar esta cidade'),
      ),
    ],
  );

  Widget _cidadesDe(BuildContext context, String uf, List<String> cidades) {
    final termo = normalizar(_busca.text);
    final achadas = [
      for (final nome in cidades)
        if (termo.isEmpty || normalizar(nome).contains(termo)) nome,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Espaco.s4, 0, Espaco.s4, Espaco.s2),
          child: TextField(
            controller: _busca,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'Buscar cidade', prefixIcon: Icon(Icons.search)),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: achadas.length,
            itemBuilder: (context, i) => ListTile(
              title: Text(achadas[i]),
              onTap: () => Navigator.pop(context, (achadas[i], uf)),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final uf = _uf;
    final cidades = _cidades;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Espaco.s4, Espaco.s4, Espaco.s2, Espaco.s2),
            child: Row(
              children: [
                Expanded(child: Text(uf == null ? 'Escolha o estado' : 'Cidades de $uf', style: t.titleMedium)),
                if (uf != null) TextButton(onPressed: _voltarAoEstado, child: const Text('Trocar estado')),
              ],
            ),
          ),
          Expanded(
            child: uf == null
                ? _estados(context)
                : _falhou
                ? _semLista(context, uf)
                : cidades == null
                ? const Center(child: CircularProgressIndicator())
                : _cidadesDe(context, uf, cidades),
          ),
        ],
      ),
    );
  }
}
