/*
 * Cell City facts: the organelle guide, the first-use pop-ups and the upgrade shop.
 * Kept simple for 8-14 year olds, but checked to be true.
 */
(function () {
  "use strict";

  // Organelle guide. plant: only in plant cells; animal: only in animal cells.
  const GUIDE = [
    { id: "nucleus", name: "Nucleus", job: "Control center",
      text: "The nucleus holds the cell's DNA: the instructions for building everything the cell needs. To make a protein, it copies one gene into a messenger called mRNA and sends it out to the ribosomes." },
    { id: "ribosome", name: "Ribosomes", job: "Protein builders",
      text: "Ribosomes read the mRNA message and link amino acids together, one by one, in the right order to build a protein. Some float in the cytoplasm and some sit on the rough ER." },
    { id: "rer", name: "Rough ER", job: "Protein workshop",
      text: "The rough endoplasmic reticulum (ER) is a folded network covered in ribosomes, which makes it look rough. Proteins made there are folded inside it and sent on in tiny bubbles called vesicles." },
    { id: "golgi", name: "Golgi apparatus", job: "Post office",
      text: "The Golgi apparatus sorts, packages and labels proteins, then ships them off in vesicles. Some vesicles join the cell membrane and release their proteins outside the cell." },
    { id: "mito", name: "Mitochondria", job: "Power stations",
      text: "Mitochondria release energy from food. Glucose is first split in half in the cytoplasm, then mitochondria use oxygen to finish breaking it down and store the energy in a molecule called ATP. Carbon dioxide and water are left over. One glucose can make about 30 ATP. Plant cells have mitochondria too!" },
    { id: "membrane", name: "Cell membrane", job: "Border control",
      text: "The cell membrane is a thin, flexible layer around the cell that controls what goes in and out. Tiny molecules like oxygen and carbon dioxide slip straight through it. Bigger ones like glucose need special protein doors." },
    { id: "lysosome", name: "Lysosomes", job: "Recycling crew", animal: true,
      text: "Lysosomes are bubbles full of enzymes that break down waste, worn-out parts and some invaders. The building blocks, like amino acids, can be used again." },
    { id: "vacuole", name: "Vacuoles", job: "Storage",
      text: "Vacuoles are storage bubbles for water, food and waste. Animal cells have small vacuoles. Plant cells have one huge central vacuole full of water." },
    { id: "cytoplasm", name: "Cytoplasm", job: "The city ground",
      text: "Cytoplasm is the jelly-like fluid that fills the cell. The organelles sit in it, and lots of the cell's chemical reactions happen there." },
    { id: "virus", name: "Viruses", job: "Invaders",
      text: "A virus is not a cell. It can't copy itself on its own, so it gets into a cell and hijacks the cell's ribosomes and energy to make copies of itself. The copies then burst out to attack more cells." },
    { id: "wall", name: "Cell wall", job: "Strong outer wall", plant: true,
      text: "Plant cells have a stiff cell wall outside the membrane, made mostly of cellulose. It supports the cell and helps it keep its shape. Animal cells don't have one." },
    { id: "chloro", name: "Chloroplasts", job: "Solar food factories", plant: true,
      text: "Chloroplasts are green because of chlorophyll. They use light energy to turn carbon dioxide and water into glucose and oxygen. This is called photosynthesis." },
    { id: "bigvac", name: "Central vacuole", job: "Water tank", plant: true,
      text: "A plant cell's big central vacuole holds water. When it's full, it pushes out against the cell wall and keeps the plant firm. When a plant runs low on water, the vacuoles shrink and the plant wilts." },
  ];

  // Short pop-ups the first time something happens.
  const POPUPS = {
    nucleus: "Nucleus: it copied a gene from its DNA into an mRNA message. The message is on its way to the ribosomes.",
    rer: "Ribosomes on the rough ER read the message and joined amino acids into a protein. The ER folds it and sends it on in a vesicle.",
    golgi: "Golgi apparatus: it packages and labels the protein, then ships it in a vesicle.",
    shipped: "Shipped! The vesicle joined the cell membrane and released the protein outside the cell.",
    mito: "Mitochondria: glucose + oxygen -> carbon dioxide + water + energy (ATP).",
    door: "Protein doors let glucose and amino acids through the membrane. Closed doors keep things out. Oxygen slips through the membrane by itself.",
    lysosome: "A lysosome broke down the waste. Its amino acids can be used again!",
    lysovirus: "A lysosome trapped the virus and broke it down.",
    virus: "A virus got in! It's heading for the ribosomes to hijack them. Tap it to send a lysosome.",
    blocked: "Blocked! With the door closed, the virus couldn't trick its way in.",
    hijack: "The virus hijacked the ribosomes and used the cell's energy to make copies of itself. The copies burst out of the cell.",
    vacuole: "Vacuole: it stored some extra glucose for later. Tap it to use the stored food.",
    cytoplasm: "Cytoplasm: the jelly that fills the cell. Organelles sit in it.",
    chloro: "Chloroplast: light + carbon dioxide + water -> glucose + oxygen. That's photosynthesis!",
    night: "No light at night, so chloroplasts can't photosynthesize. Mitochondria keep working day and night.",
    bite: "An insect bit through the cell wall and a virus got in! Most plant viruses get in through damage like this. Tap the virus to fight it.",
    silence: "The plant cell chopped up the virus's genetic instructions, so it can't copy itself.",
    wall: "Cell wall: a stiff layer, made mostly of cellulose, that supports the plant cell.",
    bigvac: "Central vacuole: the plant cell's water tank. Water comes in through the protein doors.",
  };

  const UPGRADES = [
    { id: "mito", name: "Extra mitochondrion", max: 2, cost: [300, 600],
      text: "Cells that need lots of energy, like muscle cells, have many mitochondria." },
    { id: "ribo", name: "More ribosomes", max: 3, cost: [200, 400, 600],
      text: "More ribosomes build proteins faster. Busy cells can have millions of them." },
    { id: "golgi", name: "Bigger Golgi", max: 2, cost: [200, 400],
      text: "Cells that send out lots of proteins have large Golgi stacks to package them." },
    { id: "lyso", name: "Extra lysosome", max: 2, cost: [200, 400], animal: true,
      text: "Some white blood cells are packed with lysosomes to destroy germs." },
    { id: "doors", name: "More protein doors", max: 2, cost: [200, 400],
      text: "More transport proteins in the membrane let food in faster." },
    { id: "auto", name: "Auto-power", max: 1, cost: [500],
      text: "Your mitochondria start working on their own when energy drops below half." },
    { id: "chloro", name: "Extra chloroplast", max: 2, cost: [300, 600], plant: true,
      text: "Leaf cells in full sun can have dozens of chloroplasts." },
  ];

  window.CC_FACTS = { GUIDE, POPUPS, UPGRADES };
})();
