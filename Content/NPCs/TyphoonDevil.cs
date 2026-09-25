using ChainsawManMod.Common.Systems;
using ChainsawManMod.Content.Items;
using ChainsawManMod.Content.Projectiles;
using Microsoft.Xna.Framework;
using Terraria;
using Terraria.Audio;
using Terraria.GameContent.Bestiary;
using Terraria.GameContent.ItemDropRules;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.NPCs
{
	// Hardmode boss. A spinning storm that circles the player firing spirals of wind, then becomes a vortex that
	// drags the player in, then charges. Below half health everything is faster and the spirals are denser.
	[AutoloadBossHead]
	public class TyphoonDevil : ModNPC
	{
		private const int FrameCount = 4;

		private const int StateCircle = 0;
		private const int StateVortex = 1;
		private const int StateCharge = 2;

		private ref float Timer => ref NPC.ai[0];
		private ref float State => ref NPC.ai[1];
		private ref float ChargesLeft => ref NPC.ai[2];

		private bool PhaseTwo => NPC.life < NPC.lifeMax / 2;

		public override void SetStaticDefaults() {
			Main.npcFrameCount[Type] = FrameCount;
			NPCID.Sets.MPAllowedEnemies[Type] = true;
			NPCID.Sets.BossBestiaryPriority.Add(Type);
			NPCID.Sets.SpecificDebuffImmunity[Type][BuffID.Poisoned] = true;
			NPCID.Sets.SpecificDebuffImmunity[Type][BuffID.Confused] = true;
		}

		public override void SetDefaults() {
			NPC.width = 110;
			NPC.height = 120;
			NPC.damage = 70;
			NPC.defense = 32;
			NPC.lifeMax = 32000;
			NPC.HitSound = SoundID.NPCHit1;
			NPC.DeathSound = SoundID.NPCDeath1;
			NPC.knockBackResist = 0f;
			NPC.noGravity = true;
			NPC.noTileCollide = true;
			NPC.value = Item.buyPrice(gold: 15);
			NPC.SpawnWithHigherTime(30);
			NPC.boss = true;
			NPC.npcSlots = 10f;
			NPC.aiStyle = -1;

			if (!Main.dedServ) {
				Music = MusicID.Boss2;
			}
		}

		public override void AI() {
			if (NPC.target < 0 || NPC.target == 255 || Main.player[NPC.target].dead || !Main.player[NPC.target].active) {
				NPC.TargetClosest();
			}
			Player player = Main.player[NPC.target];

			if (player.dead) {
				NPC.velocity.Y -= 0.3f;
				NPC.EncourageDespawn(10);
				return;
			}

			Timer++;
			NPC.rotation += PhaseTwo ? 0.25f : 0.15f; // always spinning

			switch ((int)State) {
				case StateCircle:
					Circle(player);
					break;
				case StateVortex:
					Vortex(player);
					break;
				case StateCharge:
					Charge(player);
					break;
			}

			for (int i = 0; i < 2; i++) {
				Dust dust = Dust.NewDustDirect(NPC.position, NPC.width, NPC.height, DustID.Cloud, 0f, 0f, 100);
				dust.noGravity = true;
				dust.velocity = (dust.position - NPC.Center).RotatedBy(MathHelper.PiOver2) * 0.05f;
			}
		}

		private void Circle(Player player) {
			float angle = Timer / 45f;
			Vector2 target = player.Center + angle.ToRotationVector2() * 380f;
			DevilUtils.FlyToward(NPC, target, PhaseTwo ? 16f : 12f, 15f);

			// Spiral of wind bolts.
			if (Timer % (PhaseTwo ? 6 : 9) == 0) {
				int arms = PhaseTwo ? 3 : 2;
				for (int i = 0; i < arms; i++) {
					float a = Timer * 0.15f + MathHelper.TwoPi * i / arms;
					DevilUtils.Shoot(NPC, NPC.Center, a.ToRotationVector2() * 7f, ModContent.ProjectileType<WindBolt>(), NPC.damage / 3);
				}
			}

			if (Timer >= 300) {
				SetState(StateVortex);
			}
		}

		private void Vortex(Player player) {
			NPC.velocity *= 0.9f;

			// Drag the player in (each client moves its own player).
			if (Main.myPlayer == player.whoAmI && Vector2.Distance(player.Center, NPC.Center) < 900f) {
				Vector2 pull = (NPC.Center - player.Center).SafeNormalize(Vector2.Zero) * (PhaseTwo ? 0.55f : 0.4f);
				player.velocity += pull;
			}

			if (Timer % 30 == 0) {
				SoundEngine.PlaySound(SoundID.Item20, NPC.Center);
			}

			if (Timer >= 150) {
				SetState(StateCharge);
				ChargesLeft = PhaseTwo ? 3 : 2;
			}
		}

		private void Charge(Player player) {
			if (Timer == 20) {
				SoundEngine.PlaySound(SoundID.Roar, NPC.Center);
				NPC.velocity = (player.Center - NPC.Center).SafeNormalize(Vector2.UnitY) * (PhaseTwo ? 24f : 19f);
				NPC.netUpdate = true;
			}
			else if (Timer < 20) {
				NPC.velocity *= 0.85f;
			}

			if (Timer >= 55) {
				ChargesLeft--;
				if (ChargesLeft > 0) {
					Timer = 0f;
					NPC.netUpdate = true;
				}
				else {
					SetState(StateCircle);
				}
			}
		}

		private void SetState(int state) {
			State = state;
			Timer = 0f;
			NPC.netUpdate = true;
		}

		public override void FindFrame(int frameHeight) {
			NPC.frameCounter++;
			if (NPC.frameCounter >= 5) {
				NPC.frameCounter = 0;
				NPC.frame.Y = (NPC.frame.Y + frameHeight) % (FrameCount * frameHeight);
			}
		}

		public override bool CanHitPlayer(Player target, ref int cooldownSlot) {
			cooldownSlot = ImmunityCooldownID.Bosses;
			return true;
		}

		public override void ModifyNPCLoot(NPCLoot npcLoot) {
			npcLoot.Add(ItemDropRule.Common(ModContent.ItemType<DevilFlesh>(), 1, 20, 35));
			npcLoot.Add(ItemDropRule.Common(ItemID.SoulofFlight, 1, 20, 30));
		}

		public override void BossLoot(ref int potionType) {
			potionType = ItemID.GreaterHealingPotion;
		}

		public override void OnKill() {
			NPC.SetEventFlagCleared(ref DownedDevilSystem.downedTyphoonDevil, -1);
		}

		public override void SetBestiary(BestiaryDatabase database, BestiaryEntry bestiaryEntry) {
			bestiaryEntry.Info.AddRange([
				new MoonLordPortraitBackgroundProviderBestiaryInfoElement(),
				new FlavorTextBestiaryInfoElement("Mods.ChainsawManMod.Bestiary.TyphoonDevil")
			]);
		}

		public override void HitEffect(NPC.HitInfo hit) {
			DevilUtils.Bleed(NPC, hit);
		}
	}
}
