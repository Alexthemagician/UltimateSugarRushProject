# Stock image generation

Built-in imagegen tool; final project asset: `assets/cafe/stock_atlas.png`.

One 6-column by 4-row atlas holds 18 ingredients followed by four recipe products. The final two cells are unused. Runtime AtlasTexture regions associate each cell with its ingredient/recipe ID. Map thumbnails reuse the three existing map illustrations as landscape crops.

## Initial prompt

Create one game-ready sprite atlas on a transparent background: exactly 6 columns by 4 rows of equally sized square cells, 24 cells total. Each icon centered within its cell with 15 percent padding, no overlap, no text, no letters, no borders. Glossy hand-painted anime patisserie inventory style, cream pink mint warm gold, burgundy delicate outlines. Row 1 left to right: white sugar cubes; cream flour sack; small edible pink purple flowers; amber caramel syrup bottle; dark chocolate syrup bottle; pink strawberry syrup bottle. Row 2 left to right: honey glob dripping from wooden dipper; clear spring water bottle with blue highlights; yellow butter pat on dish; smooth white fondant ball with rolling pin; clear pale golden sugar syrup bottle; roasted coffee beans. Row 3 left to right: curled brown-green oolong tea leaves; fresh mint leaves; ivory vanilla frosting swirl in bowl; pink strawberry frosting swirl in bowl; brown chocolate frosting swirl in bowl; three eggs. Row 4 left to right: golden butter-cloud fluffy bread buns; vanilla latte in mint cup; pink flower-shaped bonbons; strawberry celebration layer cake; empty transparent cell; empty transparent cell. Exactly this ordered grid. All objects entirely within their separate cells, consistent scale and beautiful readable silhouettes, real transparent alpha.

## Background correction prompts

Edit this exact sprite atlas. Remove ALL the colored blurry backgrounds and replace with real transparent alpha. Keep all 22 icons, exact 6 column 4 row grid placement, their existing artwork and scale unchanged. Remove background between objects and through handles too. Last two cells must be fully transparent. No new objects. This is a transparent game UI sprite sheet, absolutely no background color or gradient or checkerboard. Preserve the glossy icon artwork.

The output contained a baked checkerboard rather than alpha, so it was replaced using this final prompt:

Replace the entire checkerboard backdrop with ONE completely uniform flat pale cream color #fff3e6. No checkerboard anywhere. No gradients, shadows, patterns or texture on background. Keep the 22 food and ingredient icons exactly in the same positions in this 6 columns by 4 rows atlas, preserving their colors, details and size. Last two cells entirely solid #fff3e6. Retain all artwork, remove only background. This sheet will be displayed against cream menu cards.

Final generated source: `C:/Users/darkm/.codex/generated_images/01a07edc-d58c-7040-a29d-25766a27ea11/exec-e3ed8929-65e6-4b14-a300-e7e0533c683e.png`. The source is preserved; the project uses its own copy.
