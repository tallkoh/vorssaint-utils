// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

struct MenuBarShelfStrings {
    let title: String
    let caption: String
    let keepVisible: String
    let instructions: String
    let arrange: String
    let done: String
    let search: String
    let empty: String
    let failed: String
    let open: String
}

extension FeatureStrings {
    static func menuBarShelf(_ language: AppLanguage) -> MenuBarShelfStrings {
        switch language {
        case .enUS: return MenuBarShelfStrings(
            title: "Menu bar shelf",
            caption: "Keep a few favourites visible and open the rest from a shelf.",
            keepVisible: "Keep visible",
            instructions: "Switch on the icons you want in the menu bar. The rest stay in the shelf. Hidden icons are listed here too.",
            arrange: "Arrange",
            done: "Done",
            search: "Find a menu bar item",
            empty: "No items here. Use Arrange to add icons, or clear your search.",
            failed: "This item could not open. Use Arrange to reveal it in the menu bar.",
            open: "Open shelf")
        case .ptBR: return MenuBarShelfStrings(
            title: "Prateleira da barra de menus",
            caption: "Mantenha alguns favoritos visíveis e abra os demais na prateleira.",
            keepVisible: "Manter visível",
            instructions: "Ative os ícones que deseja na barra de menus. Os outros ficam na prateleira. Ícones ocultos também aparecem aqui.",
            arrange: "Organizar",
            done: "Concluído",
            search: "Buscar item da barra de menus",
            empty: "Nenhum item. Use Organizar para adicionar ícones ou limpe a busca.",
            failed: "Não foi possível abrir este item. Use Organizar para exibi-lo na barra de menus.",
            open: "Abrir prateleira")
        case .es: return MenuBarShelfStrings(
            title: "Bandeja de la barra de menús",
            caption: "Mantén algunos favoritos visibles y abre los demás desde la bandeja.",
            keepVisible: "Mantener visible",
            instructions: "Activa los iconos que quieres en la barra de menús. El resto queda en la bandeja. Aquí también aparecen los ocultos.",
            arrange: "Organizar",
            done: "Listo",
            search: "Buscar un elemento",
            empty: "No hay elementos. Usa Organizar para añadir iconos o borra la búsqueda.",
            failed: "No se pudo abrir este elemento. Usa Organizar para mostrarlo en la barra de menús.",
            open: "Abrir bandeja")
        case .fr: return MenuBarShelfStrings(
            title: "Tiroir de la barre des menus",
            caption: "Gardez quelques favoris visibles et ouvrez les autres depuis le tiroir.",
            keepVisible: "Garder visible",
            instructions: "Activez les icônes à garder dans la barre des menus. Les autres restent dans le tiroir. Les icônes masquées figurent aussi ici.",
            arrange: "Organiser",
            done: "Terminé",
            search: "Rechercher un élément",
            empty: "Aucun élément. Utilisez Organiser pour ajouter des icônes ou effacez la recherche.",
            failed: "Impossible d’ouvrir cet élément. Utilisez Organiser pour l’afficher dans la barre des menus.",
            open: "Ouvrir le tiroir")
        case .de: return MenuBarShelfStrings(
            title: "Menüleistenablage",
            caption: "Lassen Sie einige Favoriten sichtbar und öffnen Sie den Rest über die Ablage.",
            keepVisible: "Sichtbar lassen",
            instructions: "Aktiviere die Symbole für die Menüleiste. Der Rest bleibt in der Ablage. Auch ausgeblendete Symbole stehen hier.",
            arrange: "Anordnen",
            done: "Fertig",
            search: "Menüleisteneintrag suchen",
            empty: "Keine Einträge. Fügen Sie mit Anordnen Symbole hinzu oder leeren Sie die Suche.",
            failed: "Dieser Eintrag konnte nicht geöffnet werden. Blenden Sie ihn mit Anordnen in der Menüleiste ein.",
            open: "Ablage öffnen")
        case .it: return MenuBarShelfStrings(
            title: "Ripiano della barra dei menu",
            caption: "Tieni visibili alcuni preferiti e apri gli altri dal ripiano.",
            keepVisible: "Mantieni visibile",
            instructions: "Attiva le icone da tenere nella barra dei menu. Le altre restano nel ripiano. Qui trovi anche quelle nascoste.",
            arrange: "Organizza",
            done: "Fine",
            search: "Cerca una voce",
            empty: "Nessuna voce. Usa Organizza per aggiungere icone o cancella la ricerca.",
            failed: "Impossibile aprire questa voce. Usa Organizza per mostrarla nella barra dei menu.",
            open: "Apri ripiano")
        case .ru: return MenuBarShelfStrings(
            title: "Полка строки меню",
            caption: "Оставьте несколько избранных значков, а остальные открывайте с полки.",
            keepVisible: "Оставить видимым",
            instructions: "Включите значки для строки меню. Остальные останутся на полке. Здесь показаны и скрытые значки.",
            arrange: "Упорядочить",
            done: "Готово",
            search: "Найти значок строки меню",
            empty: "Значков нет. Добавьте их через Упорядочить или очистите поиск.",
            failed: "Не удалось открыть значок. Нажмите Упорядочить, чтобы показать его в строке меню.",
            open: "Открыть полку")
        case .uk: return MenuBarShelfStrings(
            title: "Полиця рядка меню",
            caption: "Залиште кілька улюблених значків, а решту відкривайте з полиці.",
            keepVisible: "Залишити видимим",
            instructions: "Увімкніть значки для рядка меню. Решта залишиться на полиці. Тут також показано приховані значки.",
            arrange: "Упорядкувати",
            done: "Готово",
            search: "Знайти значок рядка меню",
            empty: "Значків немає. Додайте їх через Упорядкувати або очистьте пошук.",
            failed: "Не вдалося відкрити значок. Натисніть Упорядкувати, щоб показати його в рядку меню.",
            open: "Відкрити полицю")
        case .sk: return MenuBarShelfStrings(
            title: "Polička lišty menu",
            caption: "Nechajte niekoľko obľúbených ikon viditeľných a ostatné otvárajte z poličky.",
            keepVisible: "Ponechať viditeľné",
            instructions: "Zapnite ikony, ktoré chcete v lište. Ostatné zostanú na poličke. Sú tu aj skryté ikony.",
            arrange: "Usporiadať",
            done: "Hotovo",
            search: "Nájsť položku lišty menu",
            empty: "Žiadne položky. Pridajte ikony cez Usporiadať alebo vymažte vyhľadávanie.",
            failed: "Položku sa nepodarilo otvoriť. Cez Usporiadať ju zobrazte v lište menu.",
            open: "Otvoriť poličku")
        case .tr: return MenuBarShelfStrings(
            title: "Menü çubuğu rafı",
            caption: "Birkaç favoriyi görünür tutun, diğerlerini raftan açın.",
            keepVisible: "Görünür tut",
            instructions: "Menü çubuğunda istediğiniz simgeleri açın. Diğerleri rafta kalır. Gizli simgeler de burada listelenir.",
            arrange: "Düzenle",
            done: "Bitti",
            search: "Menü çubuğu öğesi ara",
            empty: "Öğe yok. Düzenle ile simge ekleyin veya aramayı temizleyin.",
            failed: "Bu öğe açılamadı. Menü çubuğunda göstermek için Düzenle’yi kullanın.",
            open: "Rafı aç")
        case .ja: return MenuBarShelfStrings(
            title: "メニューバーシェルフ",
            caption: "お気に入りだけを表示し、残りはシェルフから開きます。",
            keepVisible: "常に表示",
            instructions: "メニューバーに表示するアイコンをオンにします。残りはシェルフに入ります。隠れたアイコンもここに表示されます。",
            arrange: "並べ替え",
            done: "完了",
            search: "メニューバー項目を検索",
            empty: "項目がありません。「並べ替え」で追加するか、検索を解除してください。",
            failed: "この項目を開けませんでした。「並べ替え」でメニューバーに表示してください。",
            open: "シェルフを開く")
        case .ko: return MenuBarShelfStrings(
            title: "메뉴 막대 선반",
            caption: "즐겨찾기 몇 개만 표시하고 나머지는 선반에서 여세요.",
            keepVisible: "계속 표시",
            instructions: "메뉴 막대에 표시할 아이콘을 켜세요. 나머지는 선반에 남습니다. 숨겨진 아이콘도 여기에 표시됩니다.",
            arrange: "정렬",
            done: "완료",
            search: "메뉴 막대 항목 검색",
            empty: "항목이 없습니다. 정렬로 아이콘을 추가하거나 검색을 지우세요.",
            failed: "항목을 열 수 없습니다. 정렬로 메뉴 막대에 표시하세요.",
            open: "선반 열기")
        case .zhHans: return MenuBarShelfStrings(
            title: "菜单栏收纳架",
            caption: "保留几个常用图标，其余从收纳架打开。",
            keepVisible: "保持可见",
            instructions: "开启要保留在菜单栏中的图标，其余图标放在托盘中。隐藏的图标也会列在这里。",
            arrange: "整理",
            done: "完成",
            search: "搜索菜单栏项目",
            empty: "没有项目。选择「整理」添加图标，或清除搜索。",
            failed: "无法打开此项目。选择「整理」让它显示在菜单栏中。",
            open: "打开收纳架")
        case .zhTW: return MenuBarShelfStrings(
            title: "選單列收納架",
            caption: "保留幾個常用圖示，其餘從收納架開啟。",
            keepVisible: "保持顯示",
            instructions: "開啟要保留在選單列的圖像，其餘圖像放在托盤中。隱藏的圖像也會列在這裡。",
            arrange: "整理",
            done: "完成",
            search: "搜尋選單列項目",
            empty: "沒有項目。選擇「整理」新增圖示，或清除搜尋。",
            failed: "無法開啟此項目。選擇「整理」讓它顯示在選單列中。",
            open: "開啟收納架")
        case .zhHK: return MenuBarShelfStrings(
            title: "選單列收納架",
            caption: "保留幾個常用圖像，其餘從收納架開啟。",
            keepVisible: "保持顯示",
            instructions: "開啟要保留在選單列的圖示，其餘圖示放在托盤中。隱藏的圖示也會列在這裡。",
            arrange: "整理",
            done: "完成",
            search: "搜尋選單列項目",
            empty: "沒有項目。選擇「整理」加入圖像，或清除搜尋。",
            failed: "無法開啟此項目。選擇「整理」讓它顯示在選單列中。",
            open: "開啟收納架")
        }
    }
}
