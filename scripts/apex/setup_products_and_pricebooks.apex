// Step 1: Activate the Standard Price Book (always exists, often inactive in dev orgs)
Pricebook2 std = [SELECT Id, IsActive FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
if (!std.IsActive) {
    std.IsActive = true;
    update std;
}
Id stdPbId = std.Id;

// Step 2: 15 shoe products with realistic catalog prices
Map<String, Decimal> catalogPrice = new Map<String, Decimal>{
    'URL-CR-001' => 89.99,   // Urla Classic Runner
    'URL-CB-002' => 49.99,   // Coastal Breeze Sandal
    'URL-AS-003' => 109.99,  // Aegean Sport Trainer
    'URL-BL-004' => 179.99,  // Bosphorus Leather Boot
    'URL-CH-005' => 159.99,  // Cappadocia Hiker Pro
    'URL-MS-006' => 69.99,   // Marmara Slip-On
    'URL-AB-007' => 24.99,   // Antalya Beach Flip-Flop
    'URL-IL-008' => 129.99,  // Istanbul Loafer
    'URL-PW-009' => 94.99,   // Pamukkale Walking Shoe
    'URL-AC-010' => 84.99,   // Ankara Court Sneaker
    'URL-BC-011' => 39.99,   // Bodrum Canvas Slipper
    'URL-TT-012' => 134.99,  // Trabzon Trail Runner
    'URL-IS-013' => 99.99,   // Izmir Street Sneaker
    'URL-KC-014' => 79.99,   // Konya Comfort Walker
    'URL-AM-015' => 189.99   // Adana Marathon Pro
};

List<Product2> products = new List<Product2>{
    new Product2(Name='Urla Classic Runner',        ProductCode='URL-CR-001', Description='Lightweight everyday running sneaker.',     IsActive=true),
    new Product2(Name='Coastal Breeze Sandal',      ProductCode='URL-CB-002', Description='Open-toe summer sandal with cushioned sole.', IsActive=true),
    new Product2(Name='Aegean Sport Trainer',       ProductCode='URL-AS-003', Description='Versatile training shoe for gym and outdoor.', IsActive=true),
    new Product2(Name='Bosphorus Leather Boot',     ProductCode='URL-BL-004', Description='Premium full-grain leather boot.',           IsActive=true),
    new Product2(Name='Cappadocia Hiker Pro',       ProductCode='URL-CH-005', Description='All-terrain waterproof hiking boot.',        IsActive=true),
    new Product2(Name='Marmara Slip-On',            ProductCode='URL-MS-006', Description='Casual slip-on with memory foam insole.',    IsActive=true),
    new Product2(Name='Antalya Beach Flip-Flop',    ProductCode='URL-AB-007', Description='Lightweight rubber flip-flop for beach.',    IsActive=true),
    new Product2(Name='Istanbul Loafer',            ProductCode='URL-IL-008', Description='Formal leather loafer with hand-stitched detail.', IsActive=true),
    new Product2(Name='Pamukkale Walking Shoe',     ProductCode='URL-PW-009', Description='Ergonomic walking shoe with arch support.',  IsActive=true),
    new Product2(Name='Ankara Court Sneaker',       ProductCode='URL-AC-010', Description='Low-profile court-style sneaker.',           IsActive=true),
    new Product2(Name='Bodrum Canvas Slipper',      ProductCode='URL-BC-011', Description='Breathable canvas slipper for warm weather.', IsActive=true),
    new Product2(Name='Trabzon Trail Runner',       ProductCode='URL-TT-012', Description='Rugged trail runner with aggressive tread.', IsActive=true),
    new Product2(Name='Izmir Street Sneaker',       ProductCode='URL-IS-013', Description='Urban streetwear sneaker.',                  IsActive=true),
    new Product2(Name='Konya Comfort Walker',       ProductCode='URL-KC-014', Description='All-day comfort walking shoe.',              IsActive=true),
    new Product2(Name='Adana Marathon Pro',         ProductCode='URL-AM-015', Description='High-performance marathon racing shoe.',     IsActive=true)
};
insert products;

// Step 3: Standard Pricebook entries (required before custom pricebook entries)
List<PricebookEntry> stdEntries = new List<PricebookEntry>();
for (Product2 p : products) {
    stdEntries.add(new PricebookEntry(
        Product2Id      = p.Id,
        Pricebook2Id    = stdPbId,
        UnitPrice       = catalogPrice.get(p.ProductCode),
        IsActive        = true,
        UseStandardPrice = false
    ));
}
insert stdEntries;

// Step 4: Two custom price books (Summer Campaign and Seller Discount)
List<Pricebook2> customBooks = new List<Pricebook2>{
    new Pricebook2(Name='Summer Campaign Price Book', Description='Seasonal summer promotion - 15% discount on all products.', IsActive=true),
    new Pricebook2(Name='Seller Discount Price Book', Description='Volume reseller pricing - 25% discount on all products.',   IsActive=true)
};
insert customBooks;
Id summerPbId = customBooks[0].Id;
Id sellerPbId = customBooks[1].Id;

// Step 5: Custom pricebook entries (15% off for Summer, 25% off for Seller)
List<PricebookEntry> customEntries = new List<PricebookEntry>();
for (Product2 p : products) {
    Decimal base = catalogPrice.get(p.ProductCode);
    customEntries.add(new PricebookEntry(
        Product2Id=p.Id, Pricebook2Id=summerPbId,
        UnitPrice=(base * 0.85).setScale(2), IsActive=true, UseStandardPrice=false
    ));
    customEntries.add(new PricebookEntry(
        Product2Id=p.Id, Pricebook2Id=sellerPbId,
        UnitPrice=(base * 0.75).setScale(2), IsActive=true, UseStandardPrice=false
    ));
}
insert customEntries;

// Step 6: Wire the 3 existing Opportunities and their Quotes to the Standard pricebook
List<Opportunity> opps = [
    SELECT Id FROM Opportunity
    WHERE Id IN ('006V900000Rh8ArIAJ','006V900000RgxYoIAJ','006V900000Rh8E5IAJ')
];
for (Opportunity o : opps) o.Pricebook2Id = stdPbId;
update opps;

List<Quote> quotes = [
    SELECT Id FROM Quote
    WHERE Id IN ('0Q0V9000002Ph73KAC','0Q0V9000002Ph8fKAC','0Q0V9000002PhAHKA0')
];
for (Quote q : quotes) q.Pricebook2Id = stdPbId;
update quotes;

System.debug('=== SETUP DONE ===');
System.debug('Products:        ' + products.size());
System.debug('Std PB entries:  ' + stdEntries.size());
System.debug('Custom PBs:      ' + customBooks.size());
System.debug('Custom entries:  ' + customEntries.size());
System.debug('Opps wired:      ' + opps.size());
System.debug('Quotes wired:    ' + quotes.size());
