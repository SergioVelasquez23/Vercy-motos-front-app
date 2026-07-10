import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
// ignore: uri_does_not_exist
import 'dart:html'
    if (dart.library.io) 'package:vercy_motos/utils/html_stub.dart'
    as html;

/// Campanita corta (dos notas superpuestas, cada una con armónicos +
/// decaimiento exponencial en vez de un tono puro — así suena a
/// "ding" de campana en vez de a beep de microondas), embebida en base64.
/// Evita depender de un asset o de un paquete nuevo (audioplayers/
/// just_audio) que no se puede verificar sin correr `flutter pub get`.
const String _beepDataUri =
    'data:audio/wav;base64,UklGRk0hAABXQVZFZm10IBAAAAABAAEAESsAABErAAABAAgAZGF0YSkhAAB/wqCKiXVXVViqvZB2lllKW5OrtnSFfU86kqWqk4JzbjphsbCKkoFgVE+LvqF3mHJJTYOdvIWDhmUueJ6ql5F1e0NLlbqMlI1uVU1ts65+k4lTQ3KOtpaEiX0xXZGplp17hFJBdLuSk5WBWFFXnrSKiptkQGGCqaOJiY9BRoCllKOFimNDVa+akZeUX1dKhq+ZgqR7RlF3mKmRiJlbOmqekaGQj3JOP5mgkZKkbV5FcKCnfqSQVkRuh6aYi5t4OlWSkZqZlH9fNn2gk4utf2ZHYIutgJ2fbj5keJ2akJeSR0WAkpCdmYpvO2CYl4OsknFNV3Wrh5SmiUFbbJGXlpGjXT5qkYeanZR9SkqJmoCjo35WVGKejoyjolBTY4aPm42rdkNUjYGTnp2HXz91l4GUro9hVVeMk4iasmdPXHyEnIurjVRDhH6KmaWPdEBij4eEr55wWVN3k4ePt4NSVXV6l4ulnmw8dX2CjqqVh0tUf413p6qCXlZljIiGsZ5eUW5yjIyepoVAZXt+gaqblVxObZBxma+WZV1ZgYeCo7JxUWdvf4qXp5tRVnd8daKgnm9SXI1xiKupcGVVdYKBkruIWWBvc4aQpKlpTm99bJSjpIFeUYR1ep+3fm5XbHqCgbmeZ1pxan6Jnq2ET2Z8aoKhp49tTnd5cY27j3ZdZ3CCdq2tfFdyZ3aAmKqcW155bXCaqJp8VWl7bnu2oH9kZmiAcJyzk1pxaG92kqGtbVtydGONpaKJY196cGymroptamN6boqvqGVubGxsi5e0gmBpfF19nqiSdFt1c2WQtJZ2b2Ryb3ujtXZrcG5jgo6ylWtigF5ukquXhV5wdGR4saKAc2prb3CTuYtscnNed4WqonxegGZjgaqakmhsc2llpaqMd3Job2qDsqBycnhfbH6eqI5ie3Beb6OdmnVtcHFZkqyYentobmZ2oq99c3xnYXaSp5xsdXhhX5eenoFzbndVfKakfoNubmRtjrWLdX1yW26GoaV8cX5pVYWdn4t7bXtaapithId1cWNqe7GZe3x/XGZ6maWNcIBzVHGYnpKEcHtjXYaujYh+dmRoa6SjhXiJY2BvkKCbdX98Wl+PnJaLeHptWHKol4iEfmZoYpKmkXeObl5kh5ekfn+CZ1KBmJiPgXl2W2KZn4qHhmxoXoChnHmOfGJbfoyliICDd05xkJmQi3t9YlmFo42IjXZpXnCWo3+KiGxWdIOgkYSChVNjhZmOkn+Ca1dwoJGIj4JsYmWIo4iFj3lWanuXlomBjl9ZeJeLlYWGc11elpWJjY5xZl96nJKCkoZdYXSNlo+BknBWaZKKlIqKemdTh5WLiJd6a11vkJmBkJFqW2+Dk5OEkYBbXImJkI6PgHJRdpKPg5uEcl5ogZyEjJZ7WWl6jJOIjo1mVXyJi46ThXxXZomSf5mOe2JlcpiIiJaMXmRyho+NipV1VW6HhouUi4RiXX2TfpKWhWdmaI+LhpGaaWFsgIiRh5iDXWCDg4eTkYlvWm+QgImZkG5oYoOLh4qieGJmfICQhpeOa1d8gYOOlox8XWWIhYGXmXhrYXeIiIOiiGhheHmNhpSUe1Zzf4CGmI+HZl98iHuQnoRvZG2CiX+clnNfdHWGhpGWi1tqe399l5KOcGBviXmInpF0amh7h36Sn4BhcHN/g46Ul2hjdoB2kZOUe2ZlhXp/l5x7b2d0gn+HoY5oa3N4f4qRnXhib4FyiJOYg3Bff3t6jaOEdWhwe4F+nZl0aHR0eoaN27iAdIV8aGp4WGeIs6p5eLmLUDlDbZqhzbV0bHtePj6EwLaYg4J3an14SWWJo6SDf7WOZk89S4ilya+Kf39eRD9ymrW1i3Z8doNxSGmCiqCXgp+Uh2IzN3yftqinkHhlWD9aeLbJjW+Lf31uVm1xdaOlf4qfpWwyN26Loqe+mHF3cTtEZbHKjnSagXRya2hebKame4CotHI+RFpwl6rDmnWKgTg6W5+7mISce3V+eV5TbqGYgIGltIBWUkJak6a4n4WYh0BAUoGnqJWTeIKFe1pVcJCHj4eTrJhxWDFQjZemqpeZhldOQ2KZtp6GfZWCdmNfaXt/oYZ9p7KEWzFRf4CZtqOTinlaMk2PtJ6BiKB6dXhmXG5/p4FtpcGNZUBTZW+UuKOQkpZiK0eDop2HkJ90fYplUWqAoHtuoL2VeFZSTWeSq5uYm6RrM0lwh6KVkJV7iJFjUWx6kH14k6yikWVOQWaKlJennaV7SklXcKidh46LkItnX2ttgoaCf5ezqG1SRGR6fpiylaCTZkVDY6eagY6Zj4NzcmJgfo6Eb4i/sXJhUVpmc5iwi6GrfUQ8X5uNhJKdiYKEgFVagI1/aYC+sH94XExbcZKhh6a3jE1CWoKDkJOTioqOhVFegYN6cnisrJOMY0VZcIOPjKqzlmZMT2p9m4yHkZSNhlpmeHV9fm6Tq6qVZk1fZ3KDlKWlpIZVRFx7nIF/nJmFim1qaW6Eh2F/qrmXcGBiWWd9lZmYs6NaQVh2kHuAoZWBlIBpXG+LhFt2o7mYf3ViTGZ5i4uUurRkS1tqf3yFm42FnYppWnSJe2B0ka+fkYJgSm1xeYSTtrh3Xlpac4OFjYmRnopvYXR/dm5zeKOsnohlU3BkbIOSpreSdFRQb4d/gIqcl4mAbGt3eH1uYpq1oIp0YmxZaIOIkrashlBRb391e4ufi4uTdF50f4JoV5KznZCGbmRVa316hrS7klZbbnBxf4eYh5Kfdll3goFmW4akm5yUdmBccHBsgqy7n2dmZ2Nyg3uOiZmfemB6fXxuY3SQnKiXfGdlbmNlg5ywr39tX154gG2IkZiYhW94cn55aWN/oa2ShnZsaV5mgIWkvpVuXmN5d2aGkpKRkn9waYWCa1l0oKmMk4ZsZGNpdnGbxaJzZmp0bGmEioqRnYlpZ42Da1puk6CNoY9saG5maGWUv6mAc21sZ3F/fYeVn49rbI5/b2Vnf5iUppBycXViYWKKrKyVf2xpaXd1cIiYl5J3cYV7eXJdbZSaoY6AfXVgY2R8lLCphWlwbnZqbIqTi5mHcnh8hXlXY46YmJCRg3BnamFqgbG1iG17cG9nboeKhKKScnCDjXlWY4SPkpWchW9zcVpfdqq2jXmFbmtscXt/hKWVdXCGjXlfaHSEkZmdh3SAdVVdb5iumoiHbG9yb256iKGSf3aCh35uamJ8lJaXjn+HdFlgZoGmp5OEcHh2amh4iJSPkHx3g4h4ald5k46RmIiHdWZlXGydrpmAeYFyZ2l2gomPnn9uhJJ9ald2i4SNoI2De3dnUmCUq5uDhodvaHBxdoORo4BshpN+cF5xfX+OoIyFg4NnUF6HnJ+NjIdvcHZmboKQnoRyho2Ae2hocICQl4yNiohrVl50i6WWjIZ5eHZgbIGIlY1+gISIhm1haYGLio6Wiol1Yl1jfKiaiIeEfnNgcHt+jpeGeH2RjW9han6DgZKchoqEblpXc6SXiI2OfXNncnB2jJyKdHqYjXFqa3R8fZSago6SdllVbZaSjZKQfnhxcWRyi5eKeXqWi3l1aml5fo+RhZOYe2JZZIKOlZOMhIF3b19zh42NhHmNioV9aGN7fYWKjJSVgnFeW3GLmo6Ij4h4b2JzfYKRjnWDjJCBZ2R7eHyGkpGPjYJhVWaHmIiImIt5dWpvcnyVk3J9kJSBbWt4cXiFkYuLl49kVmN+j4aJnIp7fnBoanuUkHV9jpOCd3Jwa3uBioeMnJZqX2JxhImLmImEhnNlanmNi35/ho+JgXZrbH57gYeNmph3bGBjfY2Ij4yPiXVobHSBh4mAe4yShndpb35zeouMkZqHdlxceYuCiZCXh3hybmt5h5B+c4yYhnpwc3pteIuGiZ2Wfl1ddYN9hpGYhYB9bWN3hZF9cYuYhYB4c3NveoV+hp2dhGRjb3d9h42ViImEbGF3gIuAd4WRh4l+cnBzeX16h5idjHFpZ21/hoSRj46GbmZ1d4WGfH2JjJF+cnJ4dnR5iI2YmH9sY2mAgXuPlZCHd25xboKLgHWDkpN8eHd4cnJ6hoCVoYpuZGl+eXaOlY2JgnZqaYGLfnOBlJF9gHt0cnV6gHiSppB0a2p3dHeJkIyPi3pnaoGFfnd+jo6CiHxwdXl1eXaOoZR/dGpvcnqCh42VjX5rbXx+gH55hY+Jinxye3lwdneIlpmNfGhtc3t4gJGWi4VybnR4hIRyfZCOiXx4fndud3h+jJ2Yf2pwdHhxfZKTiY59bm53hYVve5COhoB/fnRzeXZ1g56fgXB2cXRweo2OiZaEb2t4g4Jwe4mMhoaEfHN6eXByf5meh3t5bnF0doKJjZqIc293fYB3fICJi4qDe3eAdm1zfI2ckIV7bHN3cXmHj5eJfHRzeIB9enaHkImCf3yBc3B2dYCZmYt6cHh3bHOFj5GMiHdudYKAd3CHkYWChX6AdHV3b3aWnI58eHt1anOAiYyQkXpsd4F+d3CFjYOFin59eXp1a3GQmZGCf3tybnR4gomTlX1uen17enN+h4SJin1/f35ya3GGkZWJg3tzdHRufYmRk4R1enh7f3V2gYiLhn6Cgn5zb3F6iZqOhHx5eHNoe4iLkIx9eHR+g3Zwf4qKgoOGgX15dG9vgpyQg4F/enJoeYKFj5WDdnKBgnVwfYiHgIiIfX9/dm5qfZiQhYeDenRsd3qAj5aGeHWCf3Z0eoGGgoqGfIKFd29reI6OiouDfHhxcXJ/jpSKfneAe3p5dXmIhYiDf4aGd3RtcYOOj4uCgH50bW1+iYyOhnl8e397cHWJhYSDg4aEenpva3mNkoiBh4F1bm57goaTjXh6foJ7bnWIg4GEh4SCgYBvaHSKkIeEjYJ4cm92e4OVkHp7gYJ7cXWCgIKGh4CCh4Rva3GCi4iHj4J8eG9vd4GTj39+gX98d3V6foWFhIGDiYVycG54h4qIi4OCfnBrdn6LjYeBfX6Be3V0foeBgYSEiIV6dmxvg42GiIaIgHFsdXmEjI+CeoCFfHVxf4d+f4iChIeCemprgYuDhoqMgXVxc3J/ipKDeoOHenZzfYJ8gYl/goqIfGxsfYSChouMgnx2b258h5CEfYSFe3t1eH1/goZ9goqJfnJud36DhoiKhoN6bW17gYyJgYOEfYF2dHuBgYF+hYiJgnhwcHiGhYKLioZ8bm94eoeNhICBg4N2cnuCf36AhoOIiH9xbXWGgX+KjoeAdHJ0c4SPhn6Ch4R1dHt/fX6ChX2IjoNzbnOCfn2KjoeEe3RvcYGMhX+CiIR4eXl6fX+BgXyIj4R3c3F8fH+HioiKgHVtcn6GhYOChoR9fHV2gIB+gH2HjIZ+d293fH+BhoqOgnhvc3l/hoh/g4eDfnR1gn57gH+DiIiFe251fX98g42OhH50cnN7h4l8goqFfXV2gHx6gYB+hYyLe3B2e315gY2MhYV5cXB5hoh7goqGfnl4fXp9gX98g42NfXV3d3p6f4mKh4t8cXF3gIV+g4iGgX54eXmAf3x7gouNgHx3dHp7e4SIi41/dHN1e4KBg4OHhoB4eHuCfHt+gIWMhoB3cnt9dn6IjYyCe3dydoGEgX+IioB4eXuAenyAfH+MioR3dHx8dHyFi4qHgndvdYCEfn2Ji4B7fHp+en2BenuMjIV6eHt7dHqBiImLh3lvdn2Afn2HioKAfXh8fX5+eXuJi4Z/e3p4d3p8hImNiXxzeHh9gH6Ch4WEfnd8f358enyEiIqEfXh5e3l1gomMiYB4eHR7gn19hoiGfHh9f3x7fHx9hY6HfXl7fXdygYiIiod8d3J7gnx6hoqHfXx+fXx9fXt5g4+Hfn18fHdyfoSEi4yAeHN8f3t6hIiHf4B9en2AfHp4goyHgIF9e3l0en+DjI2CeXZ7e3t7gISIg4J8eX+Ae3t4foiIhYR7fHx3dnqDi4uFfnh4eH19e4GKhoJ8e4B/eX55eoKIiIN7f354c3iCh4iKhHl3eH19eH+LhoJ+fX99e4B6d36JiYJ9gX95c3d+g4aNh3t3en58dn6JhoOBfn19fYB5dn2IiIKAhH96dnZ6gISPiH17fHt7d3yEhIWEf3x9gIB4eHuCh4WDhH1+e3R2fYONiIF+e3l8eXt+hYiEfn1+gH56e3l9hoeEgn6BfXN0fYGIiYaAe3l+enh6hYmDfoB+f319fXd5hYeDgYCEf3V1fH2EiYqCenx/end5g4iDgYN9fn9/fnZ3hIeBgYOEf3h2eXmBiYyCfH5/eXh3gIWDhIR8fYGAfXd3gYOCg4SCgHx4dHd/houFgIB+eXt4e4KFhYN8f4GAfXt4fICFhIKCg4B5cnd+goiIgoB9fH53d4CGhYJ+gIB/fn14eH6Hg3+DhYJ7c3h8fYaLg399f392doCFg4GBgX5/gX54d32GgX+EhoJ+dnh4eoSLhICAgX53dn2Cg4KDgXyAg395d3uEgYCFhYKBenh2eYKJhIKBgX56eHp9g4SDgHyBg358enmAgIGDgoOFfXd1eX+EhYWBgX99eXd6hIOBgX+Bgn5/e3Z9gYKBgYWGfnl3eXqAh4eBgYGAenV5hIGAg4GAgYCBe3Z8goF+gYeHgHx5d3h+h4h/goOBe3Z4gYCBhIJ+gIKDe3d7gH9+gIWEgoB6dnZ8hIaAhISAfXh4fn+ChIF9gYODfHp6fX9/gISDhIR6dXd7gYWChIOBgHt3en6DgoB/gYKCfn16en+BfYGDhoV8d3l4fYOEhIKCgn12eH6CgICBgH+DgH54eH+BfH+Eh4V/e3p2eoKFgoGEhX13eHyBf4GEf3+Eg395eH+Ae3+DhYSCfnp1eoCDgYGFhX57eXp+f4KDfn+Eg397en1/fH+Bg4WFgHp2en2BgoGEhYB+eXd8f4GCfoCEgYB+e3t9fn5+goaHgnt4enp/goGChYOBeXZ9gH+BgIGBgYKAenp+gH17goaFg357enZ+g4B/hYWDend7fn2AgYB/gYWBe3p9gHx6gYWEhIF9eXZ9gX5/hYaDfHp7fH2BgYB9goWBfHx8f317gIKChoR9eXd7f35/hIWEf3x5e36BgIB+goSBfn17fn58fYCCiIV/fHl6fH6AgYOGgn55en6AfYF/gYKCgX96fX98e36ChoSBfnt5en9/foKHhH96eX5+fYF/f4GEg4B+fn5+fHt9gYOIg358e3t+e3+DhISCe3p8fn9+f4CBg4F/fn1/fnl7gIOGg4B+enl+fX2AhYaCfHx9fn1+gH9/g4OAfXyAf3l6gIGEhIOAenl+fXt+hYeDfX58fXx/gX1+hIR/fX2Af3l7fn+ChYSAe3t+fHp9hIaDgX97fH1+f319hIOAf3+Af3t8fH2ChoWBfX18fHt8gYSEg4B6fX59fn1+goKBgH9+gH57en2BhIWCf397e3x7foSFhYB8fX59fn9+gIGDgX5+gX98eH1/gYSEgH57fH56e4KFhIB+fn18fn99fYGEgX5+gYB9eX1+f4SGgX98fn15eoGEhIKAf3x8f399fICEgH6AgX9+enx8fYOGgoB/fn16en+Bg4SCfnx+fn19fX+DgX+Af4CBfHp7foKEgoJ/fn18enx/hISCfn1/fnx+fn2BgoGAfoCCfXp7fYCCgoSAfn5+enp9hIOBgH5/fnx/fnyAg4GAfoGCfnp7fX6AhISAfn9+e3h8g4OCgoB+fn2AfXuAhIF/foGCf318e3x/hISAgIF/e3l7gYGDg4B+fn1/fHx/goGAgICAgH98enx/g4OAgoB+fnp5foGEg4B+f35+fX1+gIGCf4CAgoF7en1+gYKCgoF/f3x5e4CDgoGAgH5+fX58foGCf3+Ag4F8e318foKDgoCAgXx4eoCCgYGBf31/fn58fIKCfn+BgoF+fH17fYGDgYCBgXx5en6AgYKDfn9/f357fIGCfn+AgYGAfXx6fYGCgYGCgn58ent/goKCf3+Afn18fICAgIB/gIKBfnx7fX6AgoKCgX9+enl+gYGBf4CAfn58e31/gYJ/gIKBfnt7fn6AgoCAgYGAfHp9f4CAgIGBgIB9e3x+gYF/gYKAf318fH2AgoCAgYKAfHt9fn+BgYGAgYF+e3x+gIB/gYGAgH58e32AgX+AgYGAfnx8fH+BgICAgoJ+e3x9f4CAgYCAgn98e31/gH+BgYGBf318e3+Bf3+AgoJ/fX18foCAgH+Bg4B9fHx+f3+BgICCgX57e3+Af4CBgYGAf317fYCAf3+BgoB+fXx9f4CAf4CDgX58fH5+f4CAgIGBgHx7fX9/f4CBgoCAfnt8f4CAf4CDgX9+fH19f4B/f4KCgH18fX5+gICAgYGBfnt8fn9/f4GCgYF/fHx9f4B+f4KCgX59fX1+gH9/gYKCfnx9fn5/f4CAgYKAfHx9f39+gIGBgYB+fHx+gH5/gYKCf319fH1/f3+AgYOAfX19fn5+gICAgoF+fHx+f35/gIGCgH99fH1/f35/gYOAfn59fX5/f3+Ag4F+fX1+fn5/gICCgoB9fH5/fn5/gYKBgH58fX9/fn6Ag4F/fn19fn5/fn+CgoB+fX5+fX9/gIGCgX98fX9+fn6AgoGBf319fn9/fn+CgoB/fX59fn9+f4GCgn99fn59fn5/gYGCgH19fn5+fX+BgYGAfn19fn99foGCgoB+fn19f35+gIGCgH1+fn5+fn+AgIKBfn19fn59foCBgYF/fn1+f359f4GCgH9/fn1+fn5/gIOBf35+fn59fn+AgoKAfn1+f319f4GCgYB/fX1/fn1+gIGBgIB+fX5+fn1/goKAf35+fn1+fn6BgoF/fn9/fX1+f4CBgYB+fn9+fX1/gYGBgH9+fn5+fX6BgoGAf39+fX5+foCBgoB+fn9+fX1+gICCgX9+fn9+fX2AgYGBf39+fn99fX+BgoB/f39+fn59f4CCgX9/f39+fX5/gIGCgH5+f399fX+AgYGAf35+f359foCCgX9/f35+fn1+f4GCgH9/f399fX5/gYGAf35/f319fn+BgYCAf35/fn19f4GBgIB/f35+fn5+gIKBf39/f319fn6AgYGAfn+Afn19foGBgIB/f39+fn19gIGAgH9/f35+fX1/gYGAf3+Afn19fn+AgYF/f39/fn19gICAgIB/f39+fH6AgYB/gIB/fn59fn+BgX9/gIB/fX1+f4CBgH9/f399fH5/gICAgH9/f359fX6BgX+AgH9/fn1+foCBgH9/gIB+fX5+f4CAgH9/gH59fX6AgICAgH9/f319fYCBgICAgIB+fn19f4GAgH+AgH59fX5/gICAf3+Af359fX+AgICAgIB/fn19f4CAgH+AgH9+fn1+gICAf4CBf359fX9/gIGAf4CAf319f4CAgICAgH9/fnx+gICAf4CBf35+fX5/gIF/f4CAf319fn9/gICAgICAfnx+f4CAgICAf39+fX1/gIB/gIGAf359fn5/gIB/gICAfn1+fn+AgICAgIB/fX1+f4B/gICAgH99fX5/gH9/gICAfn5+fX+AgH+AgIF/fX5+f3+AgICAgH9+fX5/gH+AgICAf359fX+Af3+AgIB/fn59fn+AgH+AgYB+fX5+f3+AgICAgH99fX9/f3+AgICAf359fn9/f3+AgYB/fn1+f3+Af3+BgH9+fX5/f4CAf4CAgH59fn9/f3+AgIB/f319f39/f4CBgH9+fn5+f4B/f4CBgH59fn5+f3+AgICAf31+f39/f4CAgIB/fn1+f4B/f4CBgH9+fn5+gH9/gICBf31+fn5/f3+AgIGAfn1+f39+f4CAgIB+fn1/f39/gICBf35+fn5/f39/gIGAfn5+fn9/f4CAgYB/fn5/f35/gICAgH9+fX5/f39/gIGAf35+fn9/f39/gYB/fn5+f35/f3+AgIB+fX5/fn5/gICAf39+fn9/f39/gYB/f35+fn9/f3+AgYB+fn5/fn9/f4CAgH99fn9/fn9/gICAf35+fn9/fn+AgYB/fn5+fn9/f4CBgH9+fn9+fn9/gICAgH5+fn9/fn+AgICAf35+f39+foCBgH9+f35+f39/f4CBgH5+f35+fn9/gICAf35+f39+foCAgIB/f35+f35+f4CBgH9/fn5/f39/f4GAf35+f39+f39/gIB/f35/f35+f4CAgH9/fn5/f35+f4GAf39/fn5+f39/gIGAf35/f35+f3+AgIB/fn5/fn5+f4CAgIB+fn9/fn5/gIGAf39/fn5/fn6AgYB/fn9/fn5+f4CAgIB+fn9/fn5/gICAgH9+fn9/fn6AgIB/f39/fn9+fn+AgYB/f39+fn5+f4CAgH9+f39/fn5/gICAf39+fn9+fn+AgIB/f39+fn5+f3+AgH9/f39+fn5/f4CAf39/f39+fn+AgIB/f39+f35+fn+AgH9/f39/fn5+f4CBf39/f39+fn9/gICAf39/f35+fn+AgICAf39/f35+f4CAf39/f39+fn5+gICAf39/f35+fn9/gICAf39/f35+foCAgIB/f39/fn5+f4CAf39/f35+fn5/gICAf39/f35+fn+AgIB/f39/fn5+f4CAgH9/f39/fn5/gICAf39/f35+fn9/gIB/f39/fn5+f3+AgH9/f39/fn5/f4CAf39/f39+fn5/gIB/f4B/f35+fn+AgH9/f39/fn5/f3+AgH9/f39+fn5/gIB/gH9/f39+fn+AgH9/gH9/fn5+fn+AgH9/f39+fn5/f4CAgH9/gH9+fn9/gH+Af39/f35+fn+Af39/f39/fn5+f4CAf39/gH9+fn5/f4CAf3+Af35+fn+Af4CAf39/f35+f4CAf3+AgH9+fn5+f4CAf3+Af35+fn9/f4B/f39/f35+f39/f39/f39/fn5+f4B/f3+Af39+fn5/f4B/f4CAf35+f39/gH9/f39/fn5+f39/f4CAf39/fn5/f4B/f4CAf39+fn5/gH9/f4B/f35+f39/f39/f4B/fn5/f39/f4B/f39+fn5/gH9/gIB/f35+fn+Af39/gIB/fn5+f39/f39/gH9+fn5/f39/gH+Af39+fn9/f39/gIB/f35+fn9/f39/gH9+fn5/f39/f3+AgH9+fn9/f39/gIB/f39+fn9/f39/gH9/f35+f39/f3+AgH9+fn9/fw==';

html.AudioElement? _audioElement;
bool _audioDesbloqueadoWeb = false;

html.AudioElement _obtenerAudio() {
  return _audioElement ??= html.AudioElement(_beepDataUri);
}

/// Los navegadores (Chrome/Edge/Safari) bloquean `audio.play()` por
/// JavaScript si no hubo antes una interacción real del usuario (clic/toque)
/// en la página — y el beep de notificación se dispara desde un timer en
/// segundo plano, no desde un clic directo, así que sin esto el navegador lo
/// bloquea en silencio (sin lanzar error visible).
///
/// Llamar esto en CUALQUIER primer toque/clic en la app "desbloquea" el
/// audio para el resto de la sesión: reproducirlo y pausarlo inmediatamente
/// cuenta como uso derivado de un gesto real ante el navegador, y los
/// `play()` posteriores desde el timer ya no se bloquean. No hace nada la
/// segunda vez que se llama, y no hace nada fuera de web.
void unlockNotificationAudioForWeb() {
  if (!kIsWeb || _audioDesbloqueadoWeb) return;
  try {
    final audio = _obtenerAudio();
    audio.volume = 0;
    // play() devuelve una Promise; si se llama a pause() antes de que
    // resuelva, el navegador la rechaza con AbortError. Sin este catchError
    // esa Promise rechazada queda sin manejar y explota como error no
    // capturado en la consola (aunque el audio igual queda desbloqueado).
    audio.play().catchError((_) {});
    audio.pause();
    audio.volume = 0.6;
    _audioDesbloqueadoWeb = true;
  } catch (_) {
    // Si falla, se reintentará en el próximo toque — no es grave.
  }
}

/// Reproduce un beep corto para alertar de una notificación nueva (p.ej. un
/// traslado recién solicitado). En web usa un `<audio>` con el beep embebido
/// en base64 (sin pedir un asset ni un paquete nuevo); en móvil/desktop usa
/// el sonido de sistema (`SystemSound.play`), que sí está soportado nativo
/// en Flutter sin dependencias extra.
///
/// Nunca lanza — un fallo reproduciendo sonido no debe romper el flujo de
/// notificaciones.
void playNotificationSound() {
  try {
    if (kIsWeb) {
      // Reusar el mismo <audio> evita crear un elemento nuevo cada vez.
      final audio = _obtenerAudio();
      audio.volume = 0.6;
      audio.play();
    } else {
      SystemSound.play(SystemSoundType.alert);
    }
  } catch (_) {
    // Ignorar: el sonido es una mejora de UX, no algo crítico.
  }
}
