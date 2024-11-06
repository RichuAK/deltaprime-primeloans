<template>
  <div id="modal" class="rtkn-pledge-modal-component modal-component">
    <Modal>
      <div class="modal__title">
        rTKN Pledge
      </div>

      <div class="modal-top-info-bar-wrapper">
        <div class="modal-top-info-bar">
          If the rTKN cap is not crossed by Wednesday 13th, you will receive 100% of your allocated PRIME.
          If it is crossed, you will receive the PRIME that reflects your share of the pool.
          The excess of committed rTKNs will be returned.
        </div>
      </div>

      <div class="modal-top-info">
        <div class="top-info__value">{{ available | smartRound(5, true) }}<span class="top-info__currency"> rTKN</span>
        </div>
      </div>

      <CurrencyInput v-on:newValue="pledgeValueChange"
                     :symbol="'rTKN'"
                     :logo="'rtkn.svg'"
                     :validators="validators"
                     :max="available">
      </CurrencyInput>

      <div class="reverse-swap-button">
        <DeltaIcon class="reverse-swap-icon" :size="22" :icon-src="'src/assets/icons/swap-arrow.svg'"></DeltaIcon>
      </div>

      <CurrencyInput ref="primeInput" :symbol="'PRIME'" :disabled="true" :logo="'prime.svg'"></CurrencyInput>

      <div class="transaction-summary-wrapper">
        <TransactionResultSummaryBeta>
          <div class="summary__title">
            Values after transaction:
          </div>
          <div class="summary__horizontal__divider"></div>
          <div class="summary__values">
            <div class="summary__value__pair">
              <div class="summary__label">
                rTKNs commited:
              </div>
              <div class="value__wrapper">
                <div class="summary__value">
                  {{ yourPledge + pledgeValue | smartRound(5, true) }} rTKN
                </div>
              </div>
            </div>
            <div class="summary__divider divider--long"></div>
            <div class="summary__value__pair">
              <div class="summary__label">
                ~Eligible PRIME
              </div>
              <div class="value__wrapper">
                <div class="summary__value">
                  {{ (yourPledge + pledgeValue) * conversionRatio | smartRound(5, true) }} PRIME
                </div>
              </div>
            </div>
          </div>
        </TransactionResultSummaryBeta>
      </div>

      <div class="button-wrapper">
        <Button :label="'Pledge'"
                v-on:click="submit()"
                :waiting="transactionOngoing"
                :disabled="inputValidationError">
        </Button>
      </div>
    </Modal>
  </div>
</template>

<script>
import Modal from './Modal';
import TransactionResultSummaryBeta from './TransactionResultSummaryBeta';
import CurrencyInput from './CurrencyInput';
import Button from './Button';
import Toggle from './Toggle';
import BarGaugeBeta from './BarGaugeBeta.vue';
import DeltaIcon from './DeltaIcon.vue';

export default {
  name: 'RtknPledgeModal',
  components: {
    DeltaIcon,
    BarGaugeBeta,
    Button,
    CurrencyInput,
    TransactionResultSummaryBeta,
    Modal,
    Toggle
  },

  props: {
    pledge: 0,
    assetSymbol: null,
    available: null,
    yourPledge: null,
    rtknCap: null,
    conversionRatio: null,
  },

  data() {
    return {
      pledgeValue: 0,
      validators: [],
      transactionOngoing: false,
      inputValidationError: false,
    };
  },

  mounted() {
    this.setupValidators();
  },

  methods: {
    submit() {
      this.transactionOngoing = true;
      const pledgeEvent = {
        value: this.pledgeValue,
      };
      this.$emit('PLEDGE', pledgeEvent);
    },

    pledgeValueChange(event) {
      console.log(event);
      this.pledgeValue = Number(event.value);
      const expectedPrime = event.value * this.conversionRatio;
      console.log(expectedPrime);
      this.$refs.primeInput.setValue(expectedPrime);
      this.inputValidationError = event.error;
    },

    setupValidators() {
      this.validators = [
        {
          validate: (value) => {
            if (value > this.available) {
              return 'Exceeds balance';
            }
          }
        }
      ];
    },
  }
};
</script>

<style lang="scss" scoped>
@import "~@/styles/variables";
@import "~@/styles/modal";

.rtkn-pledge-modal-component {
  .value__wrapper {
    display: flex;
    flex-direction: row;
    flex-wrap: wrap;

    .asset__icon {
      cursor: pointer;
      width: 20px;
      height: 20px;
      opacity: var(--asset-table-row__icon-opacity);
    }

    .summary__value:last-child {
      margin-left: 5px;
    }
  }

  .reverse-swap-button {
    position: relative;
    margin: 28px auto;
    height: 40px;
    width: 40px;
    border: var(--swap-modal__reverse-swap-button-border);
    background: var(--swap-modal__reverse-swap-button-background);
    box-shadow: var(--swap-modal__reverse-swap-button-box-shadow);
    border-radius: 999px;
    pointer-events: none;

    .reverse-swap-icon {
      position: absolute;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      background: var(--swap-modal__reverse-swap-icon-color);
    }
  }

  .modal-top-info-bar {
    text-align: center;
  }
}

</style>
